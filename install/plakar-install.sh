#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Baptiste
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://plakar.io/

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Installing Dependencies
msg_info "Installing Dependencies"
$STD apt-get install -y \
  ca-certificates \
  golang
msg_ok "Installed Dependencies"

# Setup App
msg_info "Setup Plakar"
go install github.com/PlakarKorp/plakar@latest
msg_ok "Setup Plakar"

# Repository creation
msg_info "Repository creation"
read -p "Enter the repository passphrase: " REPO_PASS
read -p "Confirm the repository passphrase: " REPO_PASS_CONFIRM
if [ "$REPO_PASS" != "$REPO_PASS_CONFIRM" ]; then
  echo "Passphrases do not match"
  exit 1
fi
plakar at /var/backups create <<EOF
$REPO_PASS
$REPO_PASS
EOF
msg_ok "Repository creation"

# Creating Service
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/plakar.service
[Unit]
Description=Plakar UI Service
After=network.target
[Service]
ExecStart=plakar at /var/backups ui
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now plakar
msg_ok "Created Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
