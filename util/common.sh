#!bash

set -e

readonly red="$(tput setaf 1)"
readonly green="$(tput setaf 2)"
readonly blue="$(tput setaf 4)"
readonly reset="$(tput sgr 0)"

log() { echo >&2 "$@"; }
info() { log "${blue}--> $*${reset}"; }
ok() { log "${green}==> $*${reset}"; }
err() { log "${red}==> $*${reset}"; }
die() { err "$@"; exit 1; }

account-id() {
  aws sts get-caller-identity | jq -r .Account
}

ip-wan() {
  curl -fsS https://api.ipify.org/
}

vpc-id() {
  aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=lyra' | \
    jq -r '.Vpcs[0].VpcId'
}

vpc-subnet() {
  local VPC_ID="$1"
  aws ec2 describe-vpcs --vpc-ids "$VPC_ID" | jq -r '.Vpcs[].CidrBlock'
}

subnet-select() {
  local VPC_ID="$1"
  [[ -n "$VPC_ID" ]] || VPC_ID="$(vpc-id)"

  aws ec2 describe-subnets \
      --filters "Name=vpc-id,Values=${VPC_ID},Name=tag:Role,Values=public" | \
    jq -r '.Subnets[].SubnetId' |
    sort -R |
    head -1
}

sg-create-temporary() {
  local SG_NAME="$1"
  local AUTHORIZED_IP="$2"
  local VPC_ID="$3"
  [[ -n "$AUTHORIZED_IP" ]] || AUTHORIZED_IP="$(ip-wan)"
  [[ -n "$VPC_ID" ]] || VPC_ID="$(vpc-id)"

  local SG_ID VPC_SUBNET

  VPC_SUBNET="$(vpc-subnet "$VPC_ID")"

  SG_ID="$(aws ec2 create-security-group \
              --vpc-id "$VPC_ID" \
              --group-name "${SG_NAME}-$(date -u +%Y-%m-%dT%H:%M:%S)" \
              --description "Temporary security group" |
            jq -r .GroupId)"

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${AUTHORIZED_IP}/32"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol all \
    --cidr "${VPC_SUBNET}"

  ok "Created security group and authorized ingress from ${AUTHORIZED_IP} and ${VPC_SUBNET}."
  echo "$SG_ID"
}

ami-latest() {
  local AMI_NAME="$1"
  local ACCOUNT="$2"
  [[ -n "$ACCOUNT" ]] || ACCOUNT="$(account-id)"

  local SOURCE_AMI_FILTERS FORMATTED_AMI_FILTER SOURCE_AMI

  SOURCE_AMI_FILTERS="$(jq --arg name "$AMI_NAME" -n '{
    name: $name,
    "virtualization-type": "hvm",
    "root-device-type": "ebs",
  }')"
  FORMATTED_AMI_FILTER="$(echo "$SOURCE_AMI_FILTERS" |
                            jq '[.|to_entries[]|{Name: .key, Values: [.value]}]')"
  SOURCE_AMI="$(aws ec2 describe-images --owners "$ACCOUNT" \
                    --filters "$FORMATTED_AMI_FILTER" |
                  jq -e '.Images | sort_by(.CreationDate) | last')"

  ok "$(echo "$SOURCE_AMI" | \
          jq -r '"Found latest image \(.ImageId) (\(.CreationDate))"')"
  echo "$SOURCE_AMI" | jq -r .ImageId
}

instance-wait-ready() {
  local INSTANCE_ID="$1"
  local SSH_USER="${2:-lyra}"
  local SSH_IDENTITY="${3:-$HOME/.ssh/id_ed25519}"

  local INSTANCE_STATUS PUBLIC_IP

  info 'Waiting for EIP.'
  sleep 2
  for _ in $(seq 60); do
    INSTANCE_STATUS="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" |
      jq '.Reservations[0].Instances[0]')"
    if echo "$INSTANCE_STATUS" | jq -e '.PublicIpAddress' >/dev/null; then
      PUBLIC_IP="$(echo "$INSTANCE_STATUS" | jq -r '.PublicIpAddress')"
      break
    else
      sleep 5
    fi
  done
  ok "Instance has IP ${PUBLIC_IP}."

  info 'Waiting for SSH to come up.'
  for _ in $(seq 60); do
    if ssh -i "$SSH_IDENTITY" -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
      "${SSH_USER}@${PUBLIC_IP}" 'true' 2>/dev/null; then
      break
    else
      sleep 2
    fi
  done
  ok 'SSH is ready.'

  echo "$PUBLIC_IP"
}
