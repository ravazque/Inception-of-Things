#!/bin/bash
# Install Argo CD (when it is not in the cluster yet) and point it at the local
# GitLab: same GitOps loop as Part 3, on-premise source repository.
set -e

CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

if kubectl -n argocd get deploy argocd-server >/dev/null 2>&1; then
  echo "==> Argo CD is already installed, reusing it"
else
  echo "==> Installing Argo CD"
  # Server-side apply: the Argo CD CRDs are too large for the client-side
  # last-applied-configuration annotation (262144 byte limit).
  kubectl apply --server-side -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

echo "==> Waiting for Argo CD to be ready"
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-server      --timeout=300s

# Points the application at the local GitLab. If Part 3 was run before, this
# replaces the GitHub source of the same application: the very thing the bonus
# asks for.
kubectl apply -f "${CONFS}/application.yaml"

echo "==> Waiting for the first sync from GitLab"
SYNC=""; HEALTH=""
for _ in $(seq 1 60); do
  SYNC="$(kubectl -n argocd get application playground \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  HEALTH="$(kubectl -n argocd get application playground \
    -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  [ "${SYNC}" = "Synced" ] && [ "${HEALTH}" = "Healthy" ] && break
  sleep 5
done

echo
echo "Namespaces:"
kubectl get ns argocd dev gitlab
echo
echo "Application: sync=${SYNC:-unknown} health=${HEALTH:-unknown}"
kubectl -n dev get deploy,svc,pods 2>/dev/null || true
echo
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
echo
echo "Argo CD UI : kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "App check  : kubectl -n dev port-forward svc/playground 8888:8888"
echo "             curl http://localhost:8888"
