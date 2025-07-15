#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/tug-benson/ProxmoxVED/New-Script-From-TB/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Baptiste
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://wiki.bruno-tatu.com/informatique/install-kresus

# App Default Values
APP="Kresus"
var_tags="${var_tags:-finance;personal}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
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
  if [[ ! -d /home/kresus/kresus_app/node_modules/kresus ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating $APP LXC"
  sudo -u kresus bash << EOF
  cd /home/kresus/kresus_app
  npm uninstall kresus
  npm install --production kresus
EOF
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container

# Install Kresus using npm
msg_info "Installing Kresus..."
pct exec $CTID -- apt-get update &>/dev/null
pct exec $CTID -- apt-get -y install npm nodejs git &>/dev/null
pct exec $CTID -- mkdir -p /home/kresus/kresus_app
pct exec $CTID -- chown -R kresus:kresus /home/kresus
pct exec $CTID -- su - kresus -c "cd /home/kresus/kresus_app && npm install --production kresus"
msg_ok "Kresus installed."

# Fix Woob installation and configure Kresus
msg_info "Fixing Woob installation..."
pct exec $CTID -- rm -rf /home/kresus/kresus_app/woob
pct exec $CTID -- su - kresus -c "git clone https://git.woob.tech/woob/woob.git -b stable /home/kresus/kresus_app/woob"
msg_ok "Woob installation fixed."

msg_info "Creating Kresus config file..."
pct exec $CTID -- su - kresus -c "/home/kresus/kresus_app/node_modules/kresus/bin/kresus.js create:config > /home/kresus/kresus_app/config.ini"
msg_ok "Kresus config file created."

msg_info "Updating Kresus service to use config file..."
cat <<'EOF' > /tmp/kresus.service
[Unit]
Description=Personal finance manager
After=network.target

[Service]
Type=simple
Restart=always
WorkingDirectory=/home/kresus
Environment=NODE_ENV=production
Environment=KRESUS_PYTHON_EXEC=python3
Environment=KRESUS_DB_TYPE=sqlite
Environment=KRESUS_DB_SQLITE_PATH=/home/kresus/kresus_app/kresus.sqlite
Environment=KRESUS_WEBOOB_DIR=/home/kresus/kresus_app/woob
ExecStart=/usr/bin/node /home/kresus/kresus_app/node_modules/kresus/bin/kresus.js --config /home/kresus/kresus_app/config.ini
User=kresus
StandardOutput=journal
StandardError=inherit
SyslogIdentifier=kresus

[Install]
WantedBy=multi-user.target
EOF
pct push $CTID /tmp/kresus.service /etc/systemd/system/kresus.service -perms 644
rm /tmp/kresus.service
pct exec $CTID -- systemctl daemon-reload
pct exec $CTID -- systemctl restart kresus.service
msg_ok "Kresus service updated."

description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9876${CL}"
