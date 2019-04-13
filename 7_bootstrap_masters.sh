#!/bin/bash
source resource_record.sh
for instance in master-0 master-1 master-2; do
  ssh -F config \
     ${instance} < ../bootstrap_control_plane.sh
done