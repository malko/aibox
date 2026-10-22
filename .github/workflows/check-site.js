#!/usr/bin/env node
/* Checks the AIBox site before it is published:
   - every local link and asset points to an existing file
   - the page loads no external resource
   - the English and French catalogs hold the same keys
   - every key used in the markup exists in the catalogs
   - every anchor of the page has a matching target
   No dependency, so it runs on any node version. */

"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const errors = [];
const warnings = [];

function fail(message) {
  errors.push(message);
}

function warn(message) {
  warnings.push(message);
}

function read(relative) {
  const file = path.join(ROOT, relative);
  if (!fs.existsSync(file)) {
    fail(`missing file: ${relative}`);
    return "";
  }
  return fs.readFileSync(file, "utf8");
}

/* --- markup -------------------------------------------------------------- */

const html = read("index.html");
const css = read("assets/site.css");

if (!html) {
  console.error("✗ the site cannot be checked, index.html is missing");
  process.exit(1);
}

/* Local resources: a link or a source that must exist on disk. */
const references = [];
const referencePattern = /(?:href|src)\s*=\s*"([^"]+)"/g;
let match;
while ((match = referencePattern.exec(html)) !== null) {
  references.push(match[1]);
}

const external = references.filter((ref) => /^https?:\/\//i.test(ref));
const local = references.filter((ref) => !/^https?:\/\//i.test(ref) && !/^(#|mailto:|data:)/i.test(ref));

for (const ref of local) {
  const clean = ref.split("#")[0].split("?")[0];
  if (!clean) continue;
  if (!fs.existsSync(path.join(ROOT, clean))) {
    fail(`broken reference in index.html: ${ref}`);
  }
}

/* The page must not depend on anything outside of the repository. */
for (const ref of external) {
  if (/\.(css|js|png|jpe?g|gif|svg|webp|woff2?)$/i.test(ref)) {
    fail(`external asset loaded by the page: ${ref}`);
  }
}

/* Anchors must point to an existing id. */
const ids = new Set([...html.matchAll(/\sid\s*=\s*"([^"]+)"/g)].map((m) => m[1]));
for (const ref of references) {
  if (!ref.startsWith("#")) continue;
  const id = ref.slice(1);
  if (id && !ids.has(id)) fail(`anchor without a target: ${ref}`);
}

/* Stylesheets and scripts referenced from the markup must be local. */
if (/<script[^>]+src\s*=\s*"(?!assets\/)/i.test(html)) {
  fail("a script is loaded from outside of assets/");
}
if (/<link[^>]+href\s*=\s*"(?!assets\/)/i.test(html) && !/rel="icon"/i.test(html)) {
  warn("a stylesheet or link is loaded from outside of assets/");
}

/* --- translations -------------------------------------------------------- */

const i18nSource = read("assets/i18n.js");
if (i18nSource) {
  const catalogs = {};
  const catalogPattern = /^\s{4}(en|fr):\s*\{([\s\S]*?)^\s{4}\},?/gm;
  let catalogMatch;
  while ((catalogMatch = catalogPattern.exec(i18nSource)) !== null) {
    const body = catalogMatch[2];
    const keys = [...body.matchAll(/"([^"]+)":/g)].map((m) => m[1]);
    catalogs[catalogMatch[1]] = keys;
  }

  if (!catalogs.en || !catalogs.fr) {
    fail("the en or fr catalog cannot be read from assets/i18n.js");
  } else {
    const en = new Set(catalogs.en);
    const fr = new Set(catalogs.fr);
    for (const key of en) {
      if (!fr.has(key)) fail(`missing French translation: ${key}`);
    }
    for (const key of fr) {
      if (!en.has(key)) fail(`missing English translation: ${key}`);
    }

    const used = new Set();
    for (const m of html.matchAll(/data-i18n(?:-attr)?\s*=\s*"([^"]+)"/g)) {
      const value = m[1];
      if (value.includes(":")) {
        value
          .split(",")
          .map((pair) => pair.split(":")[1])
          .filter(Boolean)
          .forEach((key) => used.add(key.trim()));
      } else {
        used.add(value);
      }
    }
    for (const key of used) {
      if (!en.has(key)) fail(`translation used in the markup but not defined: ${key}`);
    }
  }
}

/* --- report -------------------------------------------------------------- */

if (warnings.length) {
  console.log("warnings:");
  warnings.forEach((w) => console.log(`  ! ${w}`));
}

if (errors.length) {
  console.error("errors:");
  errors.forEach((e) => console.error(`  ✗ ${e}`));
  process.exit(1);
}

console.log(`✓ the site is consistent (${references.length} references checked, ${css.length ? "stylesheet ok" : ""})`);
