#!/bin/bash

apt update
apt upgrade -y

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
