#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/tug-benson/ProxmoxVE/refs/heads/tug_benson_ct/misc/build.func)
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

function build_container() {
  # if [ "$VERBOSE" == "yes" ]; then set -x; fi
  NET_STRING="-net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN$MTU"
  case "$IPV6_METHOD" in
  auto) NET_STRING="$NET_STRING,ip6=auto" ;;
  dhcp) NET_STRING="$NET_STRING,ip6=dhcp" ;;
  static)
    NET_STRING="$NET_STRING,ip6=$IPV6_ADDR"
    [ -n "$IPV6_GATE" ] && NET_STRING="$NET_STRING,gw6=$IPV6_GATE"
    ;;
  none) ;;
  esac
  if [ "$CT_TYPE" == "1" ]; then FEATURES="keyctl=1,nesting=1"; else FEATURES="nesting=1"; fi
  if [ "$ENABLE_FUSE" == "yes" ]; then FEATURES="$FEATURES,fuse=1"; fi
  if [[ $DIAGNOSTICS == "yes" ]]; then post_to_api; fi
  TEMP_DIR=$(mktemp -d)
  pushd "$TEMP_DIR" >/dev/null
  if [ "$var_os" == "alpine" ]; then
    export FUNCTIONS_FILE_PATH="$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/alpine-install.func)"
  else
    export FUNCTIONS_FILE_PATH="$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func)"
  fi
  export DIAGNOSTICS="$DIAGNOSTICS"
  export RANDOM_UUID="$RANDOM_UUID"
  export CACHER="$APT_CACHER"
  export CACHER_IP="$APT_CACHER_IP"
  export tz="$timezone"
  #export DISABLEIPV6="$DISABLEIPV6"
  export APPLICATION="$APP"
  export app="$NSAPP"
  export PASSWORD="$PW"
  export VERBOSE="$VERBOSE"
  export SSH_ROOT="${SSH}"
  export SSH_AUTHORIZED_KEY
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export ENABLE_FUSE="$ENABLE_FUSE"
  export ENABLE_TUN="$ENABLE_TUN"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  export PCT_OPTIONS=" -features $FEATURES -hostname $HN -tags $TAGS $SD $NS $NET_STRING -onboot 1 -cores $CORE_COUNT -memory $RAM_SIZE -unprivileged $CT_TYPE $PW "
  # This executes create_lxc.sh and creates the container and .conf file
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/create_lxc.sh)" $?
  LXC_CONFIG="/etc/pve/lxc/${CTID}.conf"
  # USB passthrough for privileged LXC (CT_TYPE=0)
  if [ "$CT_TYPE" == "0" ]; then
    cat <<EOF>>"$LXC_CONFIG"
# USB passthrough
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id dev/serial/by-id none bind,optional,create=dir
lxc.mount.entry: /dev/ttyUSB0 dev/ttyUSB0 none bind,optional,create=file
lxc.mount.entry: /dev/ttyUSB1 dev/ttyUSB1 none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM0 dev/ttyACM0 none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM1 dev/ttyACM1 none bind,optional,create=file
EOF
  fi
  # VAAPI passthrough for privileged containers or known apps
  VAAPI_APPS=( "immich" "Channels" "Emby" "ErsatzTV" "Frigate" "Jellyfin" "Plex" "Scrypted" "Tdarr" "Unmanic" "Ollama" "FileFlows" "Open WebUI" )
  is_vaapi_app=false
  for vaapi_app in "${VAAPI_APPS[@]}"; do
    if [[ "$APP" == "$vaapi_app" ]]; then
      is_vaapi_app=true
      break
    fi
  done
  if ([ "$CT_TYPE" == "0" ] || [ "$is_vaapi_app" == "true" ]) && ([[ -e /dev/dri/renderD128 ]] || [[ -e /dev/dri/card0 ]] || [[ -e /dev/fb0 ]]); then
    echo ""
    msg_custom "⚙️ " "\e[96m" "Configuring VAAPI passthrough for LXC container"
    if [ "$CT_TYPE" != "0" ]; then
      msg_custom "⚠️ " "\e[33m" "Container is unprivileged – VAAPI passthrough may not work without additional host configuration (e.g., idmap)."
    fi
    msg_custom "ℹ️ " "\e[96m" "VAAPI enables GPU hardware acceleration (e.g., for video transcoding in Jellyfin or Plex)."
    echo ""
    read -rp "➤ Automatically mount all available VAAPI devices? [Y/n]: " VAAPI_ALL
    if [[ "$VAAPI_ALL" =~ ^[Yy]$|^$ ]]; then
      if [ "$CT_TYPE" == "0" ]; then
        # PRV Container → alles zulässig
        [[ -e /dev/dri/renderD128 ]] && { echo "lxc.cgroup2.devices.allow: c 226:128 rwm" >>"$LXC_CONFIG"; echo "lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file" >>"$LXC_CONFIG"; }
        [[ -e /dev/dri/card0 ]] && { echo "lxc.cgroup2.devices.allow: c 226:0 rwm" >>"$LXC_CONFIG"; echo "lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file" >>"$LXC_CONFIG"; }
        [[ -e /dev/fb0 ]] && { echo "lxc.cgroup2.devices.allow: c 29:0 rwm" >>"$LXC_CONFIG"; echo "lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file" >>"$LXC_CONFIG"; }
        [[ -d /dev/dri ]] && { echo "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir" >>"$LXC_CONFIG"; }
      else
        # UNPRV Container → nur devX für UI
        [[ -e /dev/dri/card0 ]] && echo "dev0: /dev/dri/card0,gid=44" >>"$LXC_CONFIG"
        [[ -e /dev/dri/card1 ]] && echo "dev0: /dev/dri/card1,gid=44" >>"$LXC_CONFIG"
        [[ -e /dev/dri/renderD128 ]] && echo "dev1: /dev/dri/renderD128,gid=104" >>"$LXC_CONFIG"
      fi
    fi
  fi
  if [ "$CT_TYPE" == "1" ] && [ "$is_vaapi_app" == "true" ]; then
    if [[ -e /dev/dri/card0 ]]; then
      echo "dev0: /dev/dri/card0,gid=44" >>"$LXC_CONFIG"
    elif [[ -e /dev/dri/card1 ]]; then
      echo "dev0: /dev/dri/card1,gid=44" >>"$LXC_CONFIG"
    fi
    if [[ -e /dev/dri/renderD128 ]]; then
      echo "dev1: /dev/dri/renderD128,gid=104" >>"$LXC_CONFIG"
    fi
  fi
  # TUN device passthrough
  if [ "$ENABLE_TUN" == "yes" ]; then
    cat <<EOF>>"$LXC_CONFIG"
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
  fi
  # This starts the container and executes -install.sh
  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"
  msg_info "Customizing LXC Container"
  : "${tz:=Etc/UTC}"
  if [ "$var_os" == "alpine" ]; then
    sleep 3
    pct exec "$CTID" -- /bin/sh -c 'cat </etc/apk/repositories http://dl-cdn.alpinelinux.org/alpine/latest-stable/main http://dl-cdn.alpinelinux.org/alpine/latest-stable/community EOF'
    pct exec "$CTID" -- ash -c "apk add bash newt curl openssh nano mc ncurses >/dev/null"
  else
    sleep 3
    pct exec "$CTID" -- bash -c "sed -i '/$LANG/ s/^# //' /etc/locale.gen"
    pct exec "$CTID" -- bash -c "locale_line=\$(grep -v '^#' /etc/locale.gen | grep -E '^[a-zA-Z]' | awk '{print \$1}' | head -n 1) && \ echo LANG=\$locale_line >/etc/default/locale && \ locale-gen >/dev/null && \ export LANG=\$locale_line"
    if [[ -z "${tz:-}" ]]; then tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Etc/UTC"); fi
    if pct exec "$CTID" -- test -e "/usr/share/zoneinfo/$tz"; then
      pct exec "$CTID" -- bash -c "tz='$tz'; echo \"\$tz\" >/etc/timezone && ln -sf \"/usr/share/zoneinfo/\$tz\" /etc/localtime"
    else
      msg_warn "Skipping timezone setup – zone '$tz' not found in container"
    fi
    pct exec "$CTID" -- bash -c "apt-get update >/dev/null && apt-get install -y sudo curl mc gnupg2 >/dev/null"
  fi
  msg_ok "Customized LXC Container"
  
  # Kresus Installation
  msg_info "Installing Dependencies"
  pct exec $CTID -- apt-get install -y curl git make gcc build-essential python3-setuptools python3-dev python3-lxml python3-html2text python3-yaml python3-pil python3-pip nodejs npm &>/dev/null
  msg_ok "Installed Dependencies"

  msg_info "Creating Kresus user"
  pct exec $CTID -- adduser kresus --disabled-password --gecos Kresus &>/dev/null
  msg_ok "Kresus user created"

  msg_info "Installing Kresus and Woob"
  pct exec $CTID -- su - kresus -c "mkdir -p /home/kresus/kresus_app"
  pct exec $CTID -- su - kresus -c "npm install --prefix /home/kresus/kresus_app kresus"
  pct exec $CTID -- bash -c "wget https://gitlab.com/woob/woob/-/releases/3.7/downloads/woob_3.7-1_all.deb -O /tmp/woob.deb"
  pct exec $CTID -- bash -c "dpkg -i /tmp/woob.deb"
  pct exec $CTID -- bash -c "rm /tmp/woob.deb"
  msg_ok "Kresus and Woob installed"

  msg_info "Creating Kresus config file..."
  pct exec $CTID -- su - kresus -c "/home/kresus/kresus_app/node_modules/kresus/bin/kresus.js create:config > /home/kresus/kresus_app/config.ini"
  msg_ok "Kresus config file created."

  msg_info "Creating Service"
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
  pct push $CTID /tmp/kresus.service /etc/systemd/system/kresus.service -perms 644 &>/dev/null
  rm /tmp/kresus.service
  pct exec $CTID -- systemctl daemon-reload &>/dev/null
  pct exec $CTID -- systemctl enable -q --now kresus.service &>/dev/null
  msg_ok "Created Service"

  msg_info "Customizing Container"
  pct exec $CTID -- /bin/bash -c "source /dev/stdin <<<\"$FUNCTIONS_FILE_PATH\"; motd_ssh; customize"
  msg_ok "Customized Container"

  msg_info "Cleaning up"
  pct exec $CTID -- apt-get -y autoremove &>/dev/null
  pct exec $CTID -- apt-get -y autoclean &>/dev/null
  msg_ok "Cleaned"
}

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
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9876${CL}"