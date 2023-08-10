# Notes to build a linux server that runs kvm for VM's and docker for containers

## Setup prerequistes 

### Install Ubuntu 22.04
Install Ubuntu 22.04 Server (ubuntu-22.04.2-live-server-amd64.iso)

Hint, checkout Ventoy to boot from iso: https://www.ventoy.net

### Upgrade packages
```
sudo apt-get update
sudo apt-get upgrade -y
```

### Upgrade to HWE Kernel
Can't remember why I did this...
```
hwe-support-status --verbose
sudo apt install linux-image-generic-hwe-22.04
sudo reboot
```

### Add your user to sudoers with no password promt 
`sudo sh -c 'echo "andrew ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers'`
	
### Generate a new Private/Public Key or copy your existing one
If you want to run kcli from your laptop then copy yours to the server. This is used by kcli later to copy the public key into the VM's automatically
```
scp ~/.ssh/id_rsa.pub 192.168.0.4:/home/andrew/.ssh/
scp ~/.ssh/id_rsa 192.168.0.4:/home/andrew/.ssh/
```

### Enable dmesg for non root user
Annoys me having to sudo this...

`sudo sed -i 's/^# kernel\.dmesg_restrict/kernel\.dmesg_restrict/' /etc/sysctl.d/10-kernel-hardening.con`

`sudo service procps restart`

### Create a Bridge network
This is used by KVM and docker to add vms or containers to your host network so they are accessable by other machines on your local network
```
sudo mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
cat <<EOF | tee /etc/netplan/01-bridge-network.yaml
network:
  version: 2
  ethernets:
    enp0s31f6:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      dhcp4: false
      dhcp6: false
      addresses: 
      - 192.168.0.4/24
      routes:
      - to: default
        via: 192.168.0.1
      nameservers:
        addresses:
        - 192.168.0.1
      interfaces:
        - enp0s31f6
EOF
```

Now apply it `sudo netplan apply`

## Install Docker
> **_NOTE:_**  If you don't want to run containers on the host machine then you can skip this Install docker section.

### Before Installing docker - setup IPTables to allow br0 forwarding
This is needed because rules that docker adds to IPTables when it starts prevents network communication for KVM VM's
https://serverfault.com/questions/963759/docker-breaks-libvirt-bridge-network

```
sudo iptables -N DOCKER-USER 2>/dev/null || true
sudo iptables -C DOCKER-USER -i br0 -o br0 -j ACCEPT >/dev/null 2>&1 || 
sudo iptables -I DOCKER-USER -i br0 -o br0 -j ACCEPT
sudo apt install iptables-persistent # Answer yes to saving iptables rules to /etc/iptables/rules.v4
```

IPTables rules now should look something like this:

```
sudo iptables -S
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
-N DOCKER-USER
-A DOCKER-USER -i br0 -o br0 -j ACCEPT
```

The /etc/iptables/rules.v4 rules file should look something like this:

```
cat /etc/iptables/rules.v4
# Generated by iptables-save v1.8.4 on Fri Jan  6 07:22:43 2023
*filter
:INPUT ACCEPT [117:10777]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [48:4608]
:DOCKER-USER - [0:0]
-A DOCKER-USER -i br0 -o br0 -j ACCEPT
COMMIT
# Completed on Fri Jan  6 07:22:43 2023
```

After installing docker (more specifically starting the docker service) it will add bunch more rules for itself but this one allows our br0 bridge network to still function for the KVM VM's

### Ok, now Install Docker
https://docs.docker.com/engine/install/ubuntu/
```
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

### Install docker-compose
```
wget https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64
chmod +x chmod +x docker-compose-linux-x86_64
sudo mv docker-compose-linux-x86_64 /usr/local/bin
```

## Install KVM & Libvirt
Install kvm packages, commands taken from: https://linuxhint.com/install-kvm-ubuntu-22-04/
```
sudo apt install qemu-kvm libvirt-daemon-system virtinst libvirt-clients bridge-utils genisoimage
sudo nano /etc/libvirt/qemu.conf # set user:andrew
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo usermod -aG kvm $USER
sudo usermod -aG libvirt $USER
```

### Create a directory for your images/disk files to be kept
Ideally on a seperate drive/partition to make sure we don't fill up the root partition
```
sudo mkdir /mnt/2TB/kvm-images/
sudo setfacl -m u:andrew:rwx /mnt/2TB/kvm-images #Think I needed this? need to check
```

### Install kcli
https://github.com/karmab/kcli
kcli is a python wrapper around kvm to allow you to quickly download images, create vms, including declaratively 
```
curl -fsSL https://dl.cloudsmith.io/public/karmab/kcli/gpg.F9EA2C192F1D6BB6.key | sudo gpg --dearmor -o /usr/share/keyrings/karmab-kcli-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/karmab-kcli-archive-keyring.gpg] https://dl.cloudsmith.io/public/karmab/kcli/deb/ubuntu jammy main" >> /etc/apt/sources.list.d/karmab-kcli.list
echo "deb-src [signed-by=/usr/share/keyrings/karmab-kcli-archive-keyring.gpg] https://dl.cloudsmith.io/public/karmab/kcli/deb/ubuntu jammy main" >> /etc/apt/sources.list.d/karmab-kcli.list

apt update
# curl -1sLf https://dl.cloudsmith.io/public/karmab/kcli/cfg/setup/bash.deb.sh | sudo -E bash
sudo apt-get install python3-kcli
```

### Create kvm bridge network
Try this first: `kcli create network -P bridge=true br0` # Doesn't work

```
cat <<EOF | tee host-bridge.xml
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0" />
</network>
EOF

virsh net-define ./host-bridge.xml
virsh net-start br0
virsh net-autostart br0

virsh net-list
virsh iface-list
```

### Configure kcli
```
kcli create host kvm -H 127.0.0.1 local # Did I need this?
kcli create pool -p /mnt/2TB/kvm-images/ default # Same path we created above
kcli download image ubuntu2004 -u https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img
kcli download image ubuntu2204 -u https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
kcli download image ubuntu2210
kcli create vm -i ubuntu2004 vm1 -P nets=[br0] # Test creating a vm
kcli delete vm1 # delete the vm
```


### Install kcli client on OSX
I didn't record the steps properly but I think they are:

```
xcode-select --install # Install XCode Command Line Tools
pip3 install libvirt-python # Install libvirt
pip3 install kcli # Install kcli
kcli create host kvm -H 192.168.0.4 fserver # Create a kcli config pointing to your kvm host
nano ~/.kcli/config.yml # Edit your kcli config to set your kvm host user, last line of the file (make sure you have ssh keys setup for auth)
brew install cdrtools # Install mkisofs
kcli create vm -i ubuntu2004 -P 'nets=[br0]' vm1 # Test creating a vm

```

### kcli cheat sheet
```
kcli download image <imagename>
kcli create vm -i ubuntu2004 vm1 # Create a vm named vm1 from ubuntu2004 image
kcli create vm -i ubuntu2004 vm2 -P nets=[br0] -P memory=8096 -P numcpus=4 -P cmds=['apt install nc -y'] # Create a vm named vm2 connected to bridge br0 network, with 8GB Memory and 4 CPU, installing netcat
kcli list vm # list VM's and IP of VM
kcli delete vm vm1 vm2 -y # Delete vm1 and vm2 without confirming
kcli create plan -f plan.yaml # Create vms from a plan file which can have multiple VM's and parameters
kcli list plan # show plans created
kcli delete plan <planname> # delete vms in plan

kcli list keywords # View parameters available for creating VM's
kcli info keyword <parameter> # View more details about a parameter
```

## Create K8s Cluster
This plan creates a 2 node cluster, to add more just edit the cluster.yaml

`kcli create plan -f lab2-cluster.yaml lab2`

Wait a few mins until its ready and there will be a file k8_join.sh in the vmuser home directory which you need to run on the worker(s)

```
export CONTROLLER_IP=192.168.1.110
export WORKER_IP=192.168.1.111
scp $CONTROLLER_IP:~/k8_join.sh $WORKER_IP:/tmp/k8_join.sh
ssh $WORKER_IP sudo /tmp/k8_join.sh

export WORKER_IP=192.168.1.112
scp $CONTROLLER_IP:~/k8_join.sh $WORKER_IP:/tmp/k8_join.sh
ssh $WORKER_IP sudo /tmp/k8_join.sh

export WORKER_IP=192.168.1.113
scp $CONTROLLER_IP:~/k8_join.sh $WORKER_IP:/tmp/k8_join.sh
ssh $WORKER_IP sudo /tmp/k8_join.sh
```

## Grab the KUBECONFIG for remote access from your local machine

`scp $CONTROLLER_IP:~/.kube/config lab2-kubeconfig.yaml`

## Install MetalLB
This providers LoadBalancer Service for the cluster

```
helm install metallb metallb/metallb --namespace metallb-system --create-namespace
k -n metallb-system get pod -w # Wait until pods are ready
k apply -f metal-lb-cr.yaml
```

## Install CSI Driver

### Longhorn Option (recommended)
https://longhorn.io/docs/1.5.1/deploy/install/install-with-helm/
This uses your node storage so should be faster/less issues than NFS option.

```
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --set persistence.defaultClassReplicaCount=1 --set service.ui.type=NodePort --set defaultSettings.deletingConfirmationFlag=true
```

### NFS Option
Install NFS Server on the host to use as nfs-csi driver for Kubernetes PV

```
sudo apt install nfs-kernel-server
sudo mkdir -p /mnt/nfs_share
sudo chown -R nobody:nogroup /mnt/nfs_share/
sudo chmod 777 /mnt/nfs_share/
sudo nano /etc/exports
```
Add: `/mnt/nfs_share 192.168.0.1/24(rw,sync,no_subtree_check,no_root_squash)`

```
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

```
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace csi-driver-nfs --version v4.1.0 --create-namespace
k -n csi-driver-nfs get pod -w
k apply -f nfs-csi-sc.yaml
```

### Add hosts entry
Not running a local DNS so I add a entry to /etc/hosts on each server for my onprem setup
`echo 192.168.1.105 sysdig.f.lan |sudo tee -a /etc/hosts``

## TODO 

### Create new K8s user

### Windows interactive ISO install
https://www.funtoo.org/Windows_10_Virtualization_with_KVM
https://github.com/AlekseyChudov/windows-kvm-imaging-tools
