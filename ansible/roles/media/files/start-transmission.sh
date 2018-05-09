#!/usr/bin/env bash

set -e

die() {
    echo >&2 "$0:" "$@"
    exit 1
}

readonly MEDIA_USER=media

readonly CONFIG_PATH=/etc/local/private-internet-access
readonly USERNAME_PATH="${CONFIG_PATH}/username"
readonly PASSWORD_PATH="${CONFIG_PATH}/password"
readonly SERVER_PATH="${CONFIG_PATH}/server"

[[ -f "$USERNAME_PATH" ]] || die "${USERNAME_PATH} is missing"
[[ -f "$PASSWORD_PATH" ]] || die "${PASSWORD_PATH} is missing"
[[ -f "$SERVER_PATH" ]] || die "${SERVER_PATH} is missing"

exec docker run \
    --name transmission \
    -i \
    --cap-add NET_ADMIN \
    --device /dev/net/tun \
    -v /srv/media:/data \
    -v /etc/localtime:/etc/localtime:ro \
    -e LOCAL_NETWORK=10.0.0.0/8 \
    -e "RUN_AS=${MEDIA_USER}" \
    -e PUID="$(id -u "$MEDIA_USER")" \
    -e PGID="$(id -g "$MEDIA_USER")" \
    -e OPENVPN_PROVIDER=PIA \
    -e "OPENVPN_CONFIG=$(cat "$SERVER_PATH")" \
    -e "OPENVPN_USERNAME=$(cat "$USERNAME_PATH")" \
    -e "OPENVPN_PASSWORD=$(cat "$PASSWORD_PATH")" \
    -e TRANSMISSION_HOME=/data/.transmission \
    -e TRANSMISSION_DOWNLOAD_DIR=/data/downloads \
    -e TRANSMISSION_INCOMPLETE_DIR=/data/.incomplete \
    -e TRANSMISSION_WATCH_DIR=/data/watch \
    -e TRANSMISSION_RATIO_LIMIT_ENABLED=true \
    -e TRANSMISSION_WEB_UI=combustion \
    -p 9091:9091 \
    haugene/transmission-openvpn
