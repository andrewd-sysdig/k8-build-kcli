#!/bin/bash

VMUSER=`grep 1000 /etc/passwd | cut -d ":" -f1` # Get the vmuser which should have id 1000

POD_CIDR=10.0.0.0/16
NODENAME=`hostname`
MASTER_NODE_IP_ADDR=`hostname -I |awk {'print $1'}`

### Run kubeadm init on master node to bootstrap cluster (ignore swap error since it's been turned off but not rebooted)
kubeadm init --apiserver-advertise-address=$MASTER_NODE_IP_ADDR  --apiserver-cert-extra-sans=$MASTER_NODE_IP_ADDR  --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap

### Copy in kube config for user
mkdir -p /home/$VMUSER/.kube
cp -i /etc/kubernetes/admin.conf /home/$VMUSER/.kube/config
chown -R $VMUSER:$VMUSER /home/$VMUSER/.kube

# Copy kubeconfig for root users
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
