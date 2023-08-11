#!/bin/bash

## Enable and Load Kernel modules
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

## Add Kernel settings
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

# Install containerd.io 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io

# Setup Containerd config.toml and set SystemdCgroup = true
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Configure container sockets for critctl
cat <<EOF | sudo tee -a /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

## Enable and start containerd
systemctl restart containerd
systemctl enable containerd
