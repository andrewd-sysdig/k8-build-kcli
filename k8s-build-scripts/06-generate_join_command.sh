#!/bin/bash

VMUSER=`grep 1000 /etc/passwd | cut -d ":" -f1` # Get the vmuser which should have id 1000

### Get join command for your worker nodes
echo "Now run the join command on the worker nodes"
kubeadm token create --print-join-command > /home/$VMUSER/k8_join.sh
chmod +x /home/$VMUSER/k8_join.sh
