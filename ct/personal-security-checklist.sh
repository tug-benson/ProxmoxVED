#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tteck (https://github.com/tteck)
# Co-Author: tug-benson
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Lissy93/personal-security-checklist

APP="Personal Security Checklist"
var_tags="security,tools"
var_cpu="1"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP" "https://github.com/Lissy93/personal-security-checklist"
variables
color
catch_errors

function update_script() {
  APP_DIR="/opt/personal-security-checklist"
  if [ ! -d "$APP_DIR" ]; then
    msg_error "No $APP Installation Found!"
    exit 1
  fi

  msg_info "Stopping $APP service"
  systemctl stop personal-security-checklist
  msg_ok "Stopped $APP service"

  msg_info "Updating $APP"
  cd "$APP_DIR"
  git pull
  npm install
  npm run build
  msg_ok "Updated $APP"

  msg_info "Starting $APP service"
  systemctl start personal-security-checklist
  msg_ok "Started $APP service"

  msg_info "Saving current version"
  git rev-parse HEAD >/opt/personal-security-checklist_version.txt
  msg_ok "Saved current version"
  exit 0
}

start
build_container

description

msg_ok "Completed Successfully!"
echo -e "${APP} should be reachable by going to the following URL.\n         ${BL}http://<container-ip>:7777${CL}"
