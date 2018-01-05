#!/usr/bin/env bash

set -e

die() { echo >&2 "$@"; exit 1; }

readonly ADDR="$1"
[[ -n "$ADDR" ]] || die "usage: $0 <address>"

readonly IDENTITY="${2:-$HOME/.ssh/id_ed25519.pub}"
[[ -f "$IDENTITY" ]] || die "$IDENTITY not found"

ssh-copy-id -i "$IDENTITY" "pi@${ADDR}"

ssh -S none -t "pi@${ADDR}" 'sudo bash -c "
    [[ -d /root/.ssh ]] || cp -R /home/pi/.ssh /root/.ssh &&
    chown -R root:root /root/.ssh"'

ssh -t "root@${ADDR}" '
    kill "$(ps -p "$(pgrep -u pi sshd)" -o ppid=)"
    sleep 1;
    usermod --login lyra pi &&
    usermod --home /home/lyra --move-home lyra &&
    groupmod --new-name lyra pi &&
    passwd lyra &&
    rm -fr /root/.ssh'
