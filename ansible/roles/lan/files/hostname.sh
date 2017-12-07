#!/usr/bin/env bash

set -e

readonly DOMAIN=lyra.cloud

ZONE_ID="$(aws route53 list-hosted-zones |
           jq -r --arg domain "$DOMAIN" '.HostedZones[] |
                                         select(.Name == "\($domain).") |
                                         .Id |
                                         sub("/hostedzone/"; "")')"
HOSTNAME="$(hostname --short)"
IP4="$(curl -fsS https://api.ipify.org/)"
IP6="$(curl -fsS https://v6.ident.me/)"

echo "Updating ${HOSTNAME}.${DOMAIN} in zone ${ZONE_ID}: ${IP4}; ${IP6}"

UPDATE="$(jq -n \
            --arg domain "$DOMAIN" \
            --arg hostname "$HOSTNAME" \
            --arg ipv4 "$IP4" \
            --arg ipv6 "$IP6" \
            "$(cat hostname.jq)")"

aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "$UPDATE"
