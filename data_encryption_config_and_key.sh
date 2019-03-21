#!/bin/bash
# generate encryption key
# ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# create encryption-config.yaml file
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# copy the encryption-config.yaml file to masters
for instance in master-0 master-1 master-2; do
  external_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${instance}" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
  
  scp -i kubernetes.id_rsa encryption-config.yaml ubuntu@${external_ip}:~/
done
#  replace with this
for instance in master-0 master-1 master-2; do
  scp encryption-config.yaml ${instance}:~/
done