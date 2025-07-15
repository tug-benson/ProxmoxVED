#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/tug-benson/ProxmoxVED/New-Script-From-TB/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Baptiste
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://plakar.io/

# App Default Values
APP="Plakar"
var_tags="${var_tags:-backup;file-server}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /usr/local/go/bin/plakar ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/PlakarKorp/plakar/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
  if [[ "${RELEASE}" != "$(/usr/local/go/bin/plakar version | awk '{print $3}')" ]]; then
    msg_info "Stopping $APP"
    systemctl stop plakar
    msg_ok "Stopped $APP"
    msg_info "Updating $APP to v${RELEASE}"
    go install github.com/PlakarKorp/plakar@latest
    msg_ok "Updated $APP to v${RELEASE}"
    msg_info "Starting $APP"
    systemctl start plakar
    msg_ok "Started $APP"
    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at the latest version."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"
