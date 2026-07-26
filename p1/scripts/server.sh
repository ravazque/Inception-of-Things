#!/bin/bash
# Install K3s in server (control-plane) mode, pinned to the private network.
set -e

SERVER_IP="$1"
TOKEN="$2"

# The private IP can live on a differently named NIC per provider
# (eth1, enp0s8, ...), so resolve the interface from the IP itself.
IFACE="$(ip -o -4 addr show | grep -w "${SERVER_IP}" | awk '{print $2}' | head -n1)"

curl -sfL https://get.k3s.io | K3S_TOKEN="${TOKEN}" INSTALL_K3S_EXEC="server \
  --node-ip=${SERVER_IP} \
  --advertise-address=${SERVER_IP} \
  --flannel-iface=${IFACE} \
  --tls-san=${SERVER_IP} \
  --write-kubeconfig-mode=644" sh -

# Let the vagrant user run kubectl without sudo or extra flags.
grep -q 'KUBECONFIG' /home/vagrant/.bashrc || \
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc

echo "K3s server ready on ${SERVER_IP} (iface ${IFACE})."
