#!/bin/bash

##################### START INSTALL KUBEADMIN, KUBELET, KUBECTL ############
K8S_VERSION=$1
K8S_VERSION_SHORT=$(echo $K8S_VERSION | cut -d '.' -f 1,2)

# Install required dependencies 
apt-get install -y apt-transport-https ca-certificates curl
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION_SHORT/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# Add the GPG key and apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION_SHORT/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubelet, kubeadm and kubectl. 
apt update
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION 
sudo apt-mark hold kubelet kubeadm kubectl
