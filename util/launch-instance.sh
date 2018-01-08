#!/usr/bin/env bash

set -e

. common.sh

readonly AMI_NAME_PREFIX="$1"
[[ -n "$AMI_NAME_PREFIX" ]] || die "usage: $0 <AMI name>"

AMI_ID="$(ami-latest "$AMI_NAME_PREFIX-*")"

SUBNET_ID="$(subnet-select)"
SG_ID="$(sg-create-temporary "$AMI_NAME_PREFIX"-dev)"

INSTANCE_TAGS="$(jq -n --arg name "$AMI_NAME_PREFIX" '[
                   {
                     ResourceType: "instance",
                     Tags: [{Key: "Name", Value: "\($name)-dev"}]
                   }
                 ]')"

info "Launching instance in ${SUBNET_ID}."
INSTANCE_INFO="$(aws ec2 run-instances \
                     --subnet-id "$SUBNET_ID" \
                     --image-id "$AMI_ID" \
                     --instance-type t2.micro \
                     --security-group-ids "$SG_ID" \
                     --count 1 \
                     --tag-specifications "$INSTANCE_TAGS" \
                     --enable-api-termination \
                     --associate-public-ip-address |
                   jq '.Instances[0]')"
INSTANCE_ID="$(echo "$INSTANCE_INFO" | jq -r .InstanceId)"
ok "Started instance ${INSTANCE_ID}."

instance-wait-ready "$INSTANCE_ID"
