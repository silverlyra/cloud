#!/usr/bin/env bash

#
# Prepare our base image.
#
# Due to mostly-irrational reasons, we rename the default uid=1000 Ubuntu Server user to "lyra".
# We also, possibly foolishly, bake our SSH public key into this base image.
#
# Packer doesn't work for this use case, due to the need to SSH in as another user (we use root)
# in order to rename the ubuntu user.
#

set -e

. common.sh

readonly INITIAL_KEY="${2:-$HOME/.ssh/lyra-test.pem}"
[[ -f "$INITIAL_KEY" ]] || die "$INITIAL_KEY not found"
readonly IDENTITY="${2:-$HOME/.ssh/id_ed25519.pub}"
[[ -f "$IDENTITY" ]] || die "$IDENTITY not found"

UBUNTU_RELEASE='artful-17.10'
AMI_NAME="*ubuntu-${UBUNTU_RELEASE}-amd64-server-*"

info "Finding latest ${UBUNTU_RELEASE} image."
SOURCE_AMI_ID="$(ami-latest "$AMI_NAME" 099720109477)"

SG_ID=''
INSTANCE_ID=''
CREATED_AMI_ID=''

finish() {
  # shellcheck disable=SC2181
  [[ $? -eq 0 ]] || err 'Failed.'
  [[ -z "$INSTANCE_ID" ]] || {
    info "Terminating ${INSTANCE_ID}."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" >/dev/null

    for _ in $(seq 60); do
      aws ec2 describe-instances --instance-ids "$INSTANCE_ID" | \
        jq -e '.Reservations[0].Instances[0].State.Name != "terminated"' >/dev/null || break
      sleep 5
    done
    ok "Terminated instance."
  }

  [[ -z "$SG_ID" ]] || {
    aws ec2 delete-security-group --group-id "$SG_ID"
    ok 'Deleted security group.'
  }

  [[ -z "$CREATED_AMI_ID" ]] || {
    info 'Waiting for image to enter the "available" state.'
    for _ in $(seq 60); do
      aws ec2 describe-images --image-id="$CREATED_AMI_ID" | \
        jq -e '.Images[0].State != "available"' >/dev/null || break
      sleep 5
    done
    ok "Created image (${CREATED_AMI_ID}) is ready."
  }
}
trap finish EXIT

SUBNET_ID="$(subnet-select)"
SG_ID="$(sg-create-temporary base-ami-build)"

info "Launching instance in ${SUBNET_ID}."
INSTANCE_INFO="$(aws ec2 run-instances \
                     --subnet-id "$SUBNET_ID" \
                     --image-id "$SOURCE_AMI_ID" \
                     --instance-type t2.micro \
                     --key-name "$(basename "$INITIAL_KEY" .pem)" \
                     --security-group-ids "$SG_ID" \
                     --count 1 \
                     --enable-api-termination \
                     --associate-public-ip-address |
                   jq '.Instances[0]')"
INSTANCE_ID="$(echo "$INSTANCE_INFO" | jq -r .InstanceId)"
ok "Started instance ${INSTANCE_ID}."

PUBLIC_IP="$(instance-wait-ready "$INSTANCE_ID" ubuntu "$INITIAL_KEY")"

info 'Configuring system.'

ssh -i "$INITIAL_KEY" "ubuntu@${PUBLIC_IP}" 'tee .ssh/authorized_keys >/dev/null' < "$IDENTITY"
ok "Authorized $(basename "$IDENTITY")."

ssh -S none -o StrictHostKeyChecking=no "ubuntu@${PUBLIC_IP}" \
  'sudo bash -c "
    rm -fr /root/.ssh &&
    cp -R /home/ubuntu/.ssh /root/.ssh &&
    chown -R root:root /root/.ssh"'

ssh -o StrictHostKeyChecking=no "root@${PUBLIC_IP}" '
    kill "$(ps -p "$(pgrep -u ubuntu sshd)" -o ppid=)"
    sleep 1;
    usermod --login lyra ubuntu &&
    usermod --home /home/lyra --move-home lyra &&
    groupmod --new-name lyra ubuntu &&
    cd /etc/cloud &&
    cp cloud.cfg cloud.cfg.dist &&
    sed -e "s/name: ubuntu/name: lyra/" -e "s/gecos: .*$/gecos: Lyra/" cloud.cfg.dist > cloud.cfg &&
    rm -fr /root/.ssh'
ok 'Renamed default user.'

info 'Stopping instance.'
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" >/dev/null

for _ in $(seq 60); do
  aws ec2 describe-instances --instance-ids "$INSTANCE_ID" | \
    jq -e '.Reservations[0].Instances[0].State.Name != "stopped"' >/dev/null || break
  sleep 5
done
ok 'Stopped instance.'

info 'Creating AMI.'
CREATED_AMI_ID="$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "base-ubuntu-${UBUNTU_RELEASE}-$(date -u +%Y-%m-%d-%H%M%S)" | \
  jq -r .ImageId)"

ok "Done! Created AMI ${CREATED_AMI_ID}."

aws ec2 create-tags --resources "$CREATED_AMI_ID" \
                    --tags "$(jq -n --arg src "$SOURCE_AMI_ID" \
                                 '[{Key: "Name", Value: "base"},
                                   {Key: "Source", Value: $src}]')" >/dev/null
info 'Applied AMI tags.'
