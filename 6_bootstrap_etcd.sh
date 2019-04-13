#!/bin/bash
source resource_record.sh
for instance in master-0 master-1 master-2; do
  ssh -F config \
     ${instance} < ../boostrap_etcd_cluster.sh
done