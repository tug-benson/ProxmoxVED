#!/usr/bin/env bash
# shellcheck shell=bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (https://github.com/tteck)
# Co-Author: tug-benson
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Lissy93/personal-security-checklist

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get -y install \
  curl \
  sudo \
  git \
  nodejs \
  npm \
  python3 \
  python3-pip
msg_ok "Installed Dependencies"

APP="personal-security-checklist"
CLONE_DIR="/opt/$APP"
msg_info "Cloning $APP repository"
if [ -d "$CLONE_DIR" ]; then
  rm -rf "$CLONE_DIR"
fi
git clone https://github.com/Lissy93/personal-security-checklist.git "$CLONE_DIR"
msg_ok "Cloned $APP repository"

msg_info "Installing $APP"
cd "$CLONE_DIR"

msg_info "Installing Python requirements"
if [ -f "lib/requirements.txt" ]; then
  $STD pip3 install -r lib/requirements.txt
  msg_ok "Installed Python requirements"
else
  msg_warn "lib/requirements.txt not found, skipping Python dependencies."
fi

$STD npm install
$STD npm run build
msg_ok "Installed $APP"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/personal-security-checklist.service
[Unit]
Description=Personal Security Checklist
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CLONE_DIR
Environment="PORT=7777"
ExecStart=node server/entry.mjs
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created Service"

msg_info "Starting Service"
$STD systemctl enable --now personal-security-checklist
msg_ok "Started Service"

msg_info "Saving current version"
git rev-parse HEAD >/opt/${APP}_version.txt
msg_ok "Saved current version"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"