#!/bin/bash
# Part 3 - K3d cluster + Argo CD + continuous deployment of the dev app.
# Runs directly on the host (no Vagrant). Docker must be available; every other
# tool is downloaded into ~/.local/bin, so no sudo and no package manager
# are required.
set -e

CLUSTER="iot"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
BIN="${HOME}/.local/bin"

mkdir -p "${BIN}"
export PATH="${BIN}:${PATH}"

# --- preflight -------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed. K3d runs the cluster inside containers." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: the Docker daemon is not reachable." >&2
  echo "  start it    : sudo systemctl start docker" >&2
  echo "  permissions : the user must belong to the 'docker' group (re-login after adding it)" >&2
  exit 1
fi

# --- tooling (no sudo: everything lands in ~/.local/bin) -------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl into ${BIN}..."
  KVER="$(curl -sfL https://dl.k8s.io/release/stable.txt)"
  curl -sfLo "${BIN}/kubectl" \
    "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
  chmod +x "${BIN}/kubectl"
fi

if ! command -v k3d >/dev/null 2>&1; then
  echo "Installing k3d into ${BIN}..."
  curl -sfL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
    | USE_SUDO=false K3D_INSTALL_DIR="${BIN}" bash
fi

if ! command -v argocd >/dev/null 2>&1; then
  echo "Installing the argocd CLI into ${BIN}..."
  curl -sfLo "${BIN}/argocd" \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x "${BIN}/argocd"
fi

# --- cluster ---------------------------------------------------------------
# Recreated from scratch so the demo always starts from a known state.
k3d cluster delete "${CLUSTER}" >/dev/null 2>&1 || true
k3d cluster create "${CLUSTER}" --wait

# --- namespaces ------------------------------------------------------------
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

# --- Argo CD ---------------------------------------------------------------
# Server-side apply: the Argo CD CRDs are too large for the client-side
# last-applied-configuration annotation (262144 byte limit).
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to be ready..."
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-server      --timeout=300s

# Register the application. Argo CD then pulls the manifests from the public
# repo and keeps the dev namespace in sync with it, on its own.
kubectl apply -f "${CONFS}/application.yaml"

echo "Waiting for the first sync..."
SYNC=""; HEALTH=""
for _ in $(seq 1 60); do
  SYNC="$(kubectl -n argocd get application playground \
    -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  HEALTH="$(kubectl -n argocd get application playground \
    -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  [ "${SYNC}" = "Synced" ] && [ "${HEALTH}" = "Healthy" ] && break
  sleep 5
done

# --- info ------------------------------------------------------------------
echo
echo "Namespaces:"
kubectl get ns argocd dev
echo
echo "Application: sync=${SYNC:-unknown} health=${HEALTH:-unknown}"
kubectl -n dev get deploy,svc,pods 2>/dev/null || true
echo
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
echo
echo "Argo CD UI : kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "             https://localhost:8080  (user: admin)"
echo "App check  : kubectl -n dev port-forward svc/playground 8888:8888"
echo "             curl http://localhost:8888"
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) echo "PATH note  : add ~/.local/bin to your PATH so k3d/kubectl/argocd are found." ;;
esac
