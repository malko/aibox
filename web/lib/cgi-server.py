#!/usr/bin/env python3
"""Minimal static + CGI server for the AIBox web console.

BusyBox httpd is the preferred server on Linux, but macOS has no BusyBox
package. This fallback only uses the Python standard library (available with
the Xcode Command Line Tools or Homebrew Python) and implements the subset the
console needs:

  - static files under the web root (no directory listing);
  - CGI scripts in <root>/cgi-bin, with PATH_INFO support, so that
    /cgi-bin/api.sh/services/remove runs api.sh with PATH_INFO=/services/remove;
  - every request header is forwarded to the CGI as HTTP_*, which the API needs
    for its Authorization token.

It is deliberately single-threaded, like the BusyBox setup: the console is
local-only and the API already assumes one request at a time.
"""

import mimetypes
import os
import subprocess
import sys
import urllib.parse
from email.utils import formatdate
from http.server import BaseHTTPRequestHandler, HTTPServer

MAX_BODY = 1024 * 1024


class AIBoxRequestHandler(BaseHTTPRequestHandler):
    server_version = "aibox-cgi/1.0"

    root = ""
    cgi_dir = ""

    def version_string(self):
        return self.server_version

    def do_GET(self):
        self.handle_request()

    def do_HEAD(self):
        self.handle_request(head_only=True)

    def do_POST(self):
        self.handle_request()

    def do_PUT(self):
        self.handle_request()

    def do_DELETE(self):
        self.handle_request()

    def log_message(self, fmt, *args):
        sys.stderr.write(
            "%s - - [%s] %s\n"
            % (self.address_string(), self.log_date_time_string(), fmt % args)
        )

    def handle_request(self, head_only=False):
        path, _, query = self.path.partition("?")
        path = urllib.parse.unquote(path)

        if path.startswith("/cgi-bin/"):
            self.run_cgi(path, query, head_only)
            return

        if self.command not in ("GET", "HEAD"):
            self.send_error(405, "Method Not Allowed")
            return

        self.serve_static(path, head_only)

    def run_cgi(self, path, query, head_only):
        rest = path[len("/cgi-bin/"):]
        script_name, separator, path_info = rest.partition("/")
        script_path = os.path.join(self.cgi_dir, script_name)

        if (
            not script_name
            or not os.path.isfile(script_path)
            or not os.access(script_path, os.X_OK)
        ):
            self.send_error(404, "CGI script not found")
            return

        path_info = "/" + path_info if separator else ""

        length = self.headers.get("Content-Length")
        try:
            body_length = int(length) if length else 0
        except ValueError:
            self.send_error(400, "Invalid Content-Length")
            return
        if body_length < 0 or body_length > MAX_BODY:
            self.send_error(413, "Payload Too Large")
            return
        body = self.rfile.read(body_length) if body_length else b""

        env = os.environ.copy()
        env.update(
            {
                "GATEWAY_INTERFACE": "CGI/1.1",
                "SERVER_SOFTWARE": self.version_string(),
                "SERVER_PROTOCOL": self.protocol_version,
                "SERVER_NAME": "127.0.0.1",
                "SERVER_PORT": str(self.server.server_port),
                "REMOTE_ADDR": self.client_address[0],
                "REQUEST_METHOD": self.command,
                "SCRIPT_NAME": "/cgi-bin/" + script_name,
                "SCRIPT_FILENAME": script_path,
                "PATH_INFO": path_info,
                "QUERY_STRING": query,
                "CONTENT_TYPE": self.headers.get("Content-Type", ""),
                "CONTENT_LENGTH": str(body_length),
                "PATH": os.environ.get("PATH", "/usr/bin:/bin:/usr/sbin:/sbin"),
            }
        )

        for name, value in self.headers.items():
            key = "HTTP_" + name.upper().replace("-", "_")
            if key in ("HTTP_CONTENT_TYPE", "HTTP_CONTENT_LENGTH"):
                continue
            if key in env:
                env[key] = env[key] + ", " + value
            else:
                env[key] = value

        try:
            result = subprocess.run(
                [script_path],
                input=body,
                env=env,
                cwd=self.root,
                stdout=subprocess.PIPE,
                stderr=None,
            )
        except OSError as exc:
            self.send_error(500, "Could not run the CGI script: %s" % exc)
            return

        headers_blob, _, response_body = result.stdout.partition(b"\r\n\r\n")
        if not _:
            headers_blob, _, response_body = result.stdout.partition(b"\n\n")
        if not _:
            self.send_error(502, "CGI script produced no headers")
            return

        status = 200
        reason = None
        headers = []
        for line in headers_blob.decode("iso-8859-1").replace("\r\n", "\n").split("\n"):
            if not line.strip():
                continue
            name, sep, value = line.partition(":")
            if not sep:
                continue
            name = name.strip()
            value = value.strip()
            if name.lower() == "status":
                parts = value.split(" ", 1)
                try:
                    status = int(parts[0])
                except ValueError:
                    status = 502
                reason = parts[1] if len(parts) > 1 else None
            else:
                headers.append((name, value))

        self.send_response(status, reason)
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()
        if not head_only:
            self.wfile.write(response_body)

    def serve_static(self, path, head_only):
        if path == "/":
            path = "/index.html"

        target = os.path.realpath(os.path.join(self.root, path.lstrip("/")))
        root = os.path.realpath(self.root)
        if target != root and not target.startswith(root + os.sep):
            self.send_error(403, "Forbidden")
            return

        if os.path.isdir(target):
            target = os.path.join(target, "index.html")
        if not os.path.isfile(target):
            self.send_error(404, "Not Found")
            return

        try:
            stat = os.stat(target)
            with open(target, "rb") as handle:
                content = handle.read()
        except OSError:
            self.send_error(404, "Not Found")
            return

        content_type = mimetypes.guess_type(target)[0] or "application/octet-stream"
        if content_type.startswith("text/") or content_type in (
            "application/javascript",
            "application/json",
        ):
            content_type += "; charset=utf-8"

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Last-Modified", formatdate(stat.st_mtime, usegmt=True))
        self.end_headers()
        if not head_only:
            self.wfile.write(content)


class AIBoxHTTPServer(HTTPServer):
    allow_reuse_address = True


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("Usage: cgi-server.py <port> <web-root>\n")
        return 2

    try:
        port = int(sys.argv[1])
    except ValueError:
        sys.stderr.write("Invalid port: %s\n" % sys.argv[1])
        return 2

    root = os.path.abspath(sys.argv[2])
    cgi_dir = os.path.join(root, "cgi-bin")
    if not os.path.isdir(root) or not os.path.isdir(cgi_dir):
        sys.stderr.write("Invalid web root: %s\n" % root)
        return 2

    AIBoxRequestHandler.root = root
    AIBoxRequestHandler.cgi_dir = cgi_dir

    server = AIBoxHTTPServer(("127.0.0.1", port), AIBoxRequestHandler)
    sys.stderr.write("aibox web (python) listening on 127.0.0.1:%d\n" % port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
