#!/bin/bash
source resource_record.sh
for instance in node-0 node-1 node-2; do
  ssh -F config \
     ${instance} < ../bootstrap_nodes.sh
done
# verify
kubectl get nodes