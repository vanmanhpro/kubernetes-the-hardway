#!/bin/bash
source resource_record.sh
# generate encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo "export ENCRYPTION_KEY=${ENCRYPTION_KEY}" >> resource_record.sh

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

#  replace with this
for instance in master-0 master-1 master-2; do
  scp -F config \
    encryption-config.yaml ${instance}:~/
done