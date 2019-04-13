#!/bin/bash
source resource_record.sh
function append_config(){
    cat >> config <<EOF
Host ${1}
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
hostname ${2}
IdentityFile kubernetes_hardway.id_rsa
User ubuntu
ServerAliveInterval 15
ForwardAgent yes
EOF
}

sleep 10

for instance in master-0 master-1 master-2; do
    external_ip=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${instance}" \
        --output text --query 'Reservations[].Instances[].PublicIpAddress')
    append_config ${instance} ${external_ip}
done

for instance in node-0 node-1 node-2; do
    external_ip=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${instance}" \
        --output text --query 'Reservations[].Instances[].PublicIpAddress')
    append_config ${instance} ${external_ip}
done