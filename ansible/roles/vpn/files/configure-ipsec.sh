#!/usr/bin/env bash

set -e

readonly METADATA_URL='http://169.254.169.254/2016-09-02/meta-data'

readonly AZ=$(curl -fsS "${METADATA_URL}/placement/availability-zone")
readonly REGION="${AZ%[a-z]}"
readonly LOCAL_IP=$(curl -fsS "${METADATA_URL}/local-ipv4")
readonly PUBLIC_IP=$(curl -fsS "${METADATA_URL}/public-ipv4")

readonly PSK_IN=/etc/local/ipsec.psk
PSK="$(aws --region "$REGION" kms decrypt \
           --ciphertext-blob fileb://<(base64 --decode < "$PSK_IN") \
           --output text --query Plaintext | \
         base64 --decode)"
REMOTE_IP="$(dig +short rainbow.lyra.cloud)"

export PSK LOCAL_IP PUBLIC_IP REMOTE_IP

touch /etc/ipsec.secrets
chmod 0600 /etc/ipsec.secrets
mo /etc/local/ipsec.secrets.in > /etc/ipsec.secrets

mo /etc/local/ipsec.conf.in > /etc/ipsec.conf
