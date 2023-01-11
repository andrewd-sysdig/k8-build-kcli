#!/bin/bash

### Had to add this as kubectl wouldn't work during the master script execution without it - guess it wasnt set/available yet
export KUBECONFIG=/etc/kubernetes/admin.conf

### Install Calico Network Plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
