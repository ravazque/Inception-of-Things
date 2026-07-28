#!/bin/bash
# Join this machine to the K3s cluster as an agent (worker).
set -e

SERVER_IP="$1"
WORKER_IP="$2"
TOKEN="$3"

# Resolve the NIC that holds the private IP (name varies per provider).
IFACE="$(ip -o -4 addr show | grep -w "${WORKER_IP}" | awk '{print $2}' | head -n1)"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_EXEC="agent \
  --node-ip=${WORKER_IP} \
  --flannel-iface=${IFACE}" sh -

echo "K3s agent joined ${SERVER_IP} (node IP ${WORKER_IP}, iface ${IFACE})."
