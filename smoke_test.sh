#!/bin/bash

# Data Encryption, ability to encrypt data at rest
kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"
sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C


# Deployments, ability to create and manage deployments
kubectl run nginx --image=nginx
kubectl get pods -l run=nginx

# Port Forwarding, ability to access applications remotely using portforwarding
POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:80

# exec
kubectl exec -ti $POD_NAME -- nginx -v

# services
# NodePort
kubectl expose deployment nginx --port 80 --type NodePort
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
# config SG to access the nodeport
aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port ${NODE_PORT} \
  --cidr 0.0.0.0/0
# verify
INSTANCE_NAME=$(kubectl get pod $POD_NAME --output=jsonpath='{.spec.nodeName}')
EXTERNAL_IP=$(aws ec2 describe-instances \
    --filters "Name=network-interface.private-dns-name,Values=${INSTANCE_NAME}.${AWS_REGION}.compute.internal" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
curl -I http://${EXTERNAL_IP}:${NODE_PORT}

# Untruster workloads, ability to run untrusted workloads using gVisor
# create an untrusted pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: untrusted
  annotations:
    io.kubernetes.cri.untrusted-workload: "true"
spec:
  containers:
    - name: webserver
      image: gcr.io/hightowerlabs/helloworld:2.0.0
EOF
# verification
kubectl get pods -o wide

# go to the node that has the "untrusted" pod
INSTANCE_NAME=$(kubectl get pod untrusted --output=jsonpath='{.spec.nodeName}')
INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=network-interface.private-dns-name,Values=${INSTANCE_NAME}.${AWS_REGION}.compute.internal" \
    --output text --query 'Reservations[].Instances[].PublicIpAddress')
# List containers running under gVisor
sudo runsc --root  /run/containerd/runsc/k8s.io list
# id of the "untrusted" pod
POD_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock pods --name untrusted -q)
# id of "webserver" container running in "untrusted" pod
CONTAINER_ID=$(sudo crictl -r unix:///var/run/containerd/containerd.sock ps -p ${POD_ID} -q)
# gVisor to display processes inside "webserver" container
sudo runsc --root /run/containerd/runsc/k8s.io ps ${CONTAINER_ID}



# check images/pods/containers on worker nodes using crictl, do this on all 3 nodes
sudo crictl -r unix:///var/run/containerd/containerd.sock images
sudo crictl -r unix:///var/run/containerd/containerd.sock pods
sudo crictl -r unix:///var/run/containerd/containerd.sock ps