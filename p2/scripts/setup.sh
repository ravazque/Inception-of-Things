#!/bin/bash
# Single-node K3s server, then deploy the three apps behind one Ingress.
set -e

SERVER_IP="$1"
CONFS="/home/vagrant/confs"

# The private IP can live on a differently named NIC per provider
# (eth1, enp0s8, ...), so resolve the interface from the IP itself.
IFACE="$(ip -o -4 addr show | grep -w "${SERVER_IP}" | awk '{print $2}' | head -n1)"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=${SERVER_IP} \
  --advertise-address=${SERVER_IP} \
  --flannel-iface=${IFACE} \
  --tls-san=${SERVER_IP} \
  --write-kubeconfig-mode=644" sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -q 'KUBECONFIG' /home/vagrant/.bashrc || \
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc

# The API server answers before the node registers, and "kubectl wait" fails
# when there is no node yet, so wait for the object to exist first.
echo "Waiting for the API server..."
until kubectl get nodes --no-headers 2>/dev/null | grep -q .; do sleep 3; done
kubectl wait --for=condition=Ready node --all --timeout=180s

# -R, so the manifests are found however deep the file provisioner nested them.
kubectl apply -R -f "${CONFS}"

for app in app1 app2 app3; do
  kubectl rollout status "deploy/${app}" --timeout=180s
done

# K3s installs Traefik through a Helm job on first boot; the Deployment does
# not exist until that job runs.
echo "Waiting for Traefik..."
until kubectl -n kube-system get deploy traefik >/dev/null 2>&1; do sleep 3; done
kubectl -n kube-system rollout status deploy/traefik --timeout=180s

echo
kubectl get deploy,svc,ingress
echo
echo "Ready. From the host:"
echo "  curl -H \"Host: app1.com\" http://${SERVER_IP}"
echo "  curl -H \"Host: app2.com\" http://${SERVER_IP}"
echo "  curl -H \"Host: app3.com\" http://${SERVER_IP}"
