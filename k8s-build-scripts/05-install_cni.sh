#!/bin/bash

### Had to add this as kubectl wouldn't work during the master script execution without it - guess it wasnt set/available yet
export KUBECONFIG=/etc/kubernetes/admin.conf

### Install Calico Network Plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

### Install Flannel Network Plugin
# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml