#!/bin/bash
USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"

VSCODE_DIR="$HOME_DIR/vscode-server"
mkdir "$VSCODE_DIR"

echo -n "Set vscode-server password: "
read -s VSCODE_PASSWORD

if [[ -z $VSCODE_PASSWORD ]]; then
    echo "vscode-server password can't be empty"
    exit 1
fi

cat > "$VSCODE_DIR/docker-compose.yml" << EOFWRAPPER
version: '3.8'

services:
  vscode-server:
    image: codercom/code-server:latest
    container_name: vscode-server
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - /home/$USER_NAME/git:/home/coder/git
      - ./config:/home/coder/.config
    environment:
      - TZ=UTC
      - "PASSWORD=$VSCODE_PASSWORD"
    user: "1000:1000"
    command: --bind-addr 0.0.0.0:8080 --auth password /home/coder/git
EOFWRAPPER

cd "$VSCODE_DIR"
mkdir -p "$VSCODE_DIR/config"
docker compose up -d