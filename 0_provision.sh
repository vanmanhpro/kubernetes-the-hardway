#!/bin/bash
mkdir -p artifacts
cd artifacts
rm *
touch config 
touch resource_record.sh
../1_compute_resources.sh
../2_ssh_configure.sh
../3_certificate_authority.sh
../4_kubernetes_configurations.sh
../5_data_encryption_config_and_key.sh
../6_bootstrap_etcd.sh
../7_bootstrap_masters.sh
../8_kubectl_remote_access.sh
../9_RBAC_kubelet_authorization.sh
../10_bootstrap_nodes.sh
../11_pod_network_routes.sh
../12_dns_cluster_addon.sh
