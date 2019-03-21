#!/bin/bash

# deploy kube-dns cluster add-on
curl -O https://storage.googleapis.com/kubernetes-the-hard-way/kube-dns.yaml
kubectl create -f kube-dns.yaml

# list the pods
kubectl get pods -l k8s-app=kube-dns -n kube-system

# verification
kubectl run busybox --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl get pod busybox
kubectl exec -it busybox -- nslookup kubernetes