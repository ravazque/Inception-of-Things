#!/bin/bash
# Bonus - Part 3 plus a local GitLab as the GitOps source.
# Runs on the host like Part 3: one K3d cluster with the namespaces argocd,
# dev and gitlab. Docker must be available; the rest goes to ~/.local/bin.
set -e

CLUSTER="iot"
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
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

# GitLab needs real memory. Warn instead of failing: the numbers below are a
# comfortable minimum, not a hard limit.
MEM_GB="$(awk '/MemTotal/{printf "%d", $2/1048576}' /proc/meminfo)"
if [ "${MEM_GB:-0}" -lt 8 ]; then
  echo "WARNING: this host reports ${MEM_GB} GiB of RAM."
  echo "         GitLab alone wants ~4 GiB; close other VMs/apps first."
fi

# --- tooling (no sudo: everything lands in ~/.local/bin) -------------------
if ! command -v kubectl >/dev/null 2>&1; then
  echo "==> Installing kubectl into ${BIN}"
  KVER="$(curl -sfL https://dl.k8s.io/release/stable.txt)"
  curl -sfLo "${BIN}/kubectl" \
    "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
  chmod +x "${BIN}/kubectl"
fi

if ! command -v k3d >/dev/null 2>&1; then
  echo "==> Installing k3d into ${BIN}"
  curl -sfL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
    | USE_SUDO=false K3D_INSTALL_DIR="${BIN}" bash
fi

if ! command -v argocd >/dev/null 2>&1; then
  echo "==> Installing the argocd CLI into ${BIN}"
  curl -sfLo "${BIN}/argocd" \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x "${BIN}/argocd"
fi

# --- cluster ---------------------------------------------------------------
# Reuses the Part 3 cluster when it exists, instead of building a second one.
if k3d cluster list "${CLUSTER}" >/dev/null 2>&1; then
  echo "==> Reusing the existing k3d cluster '${CLUSTER}'"
  k3d cluster start "${CLUSTER}" >/dev/null 2>&1 || true
else
  echo "==> Creating the k3d cluster '${CLUSTER}'"
  k3d cluster create "${CLUSTER}" --wait
fi
k3d kubeconfig merge "${CLUSTER}" \
  --kubeconfig-merge-default --kubeconfig-switch-context >/dev/null

# --- namespaces ------------------------------------------------------------
for ns in argocd dev gitlab; do
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
done

# --- stack -----------------------------------------------------------------
CLUSTER="${CLUSTER}" bash "${SCRIPTS}/gitlab.sh"
bash "${SCRIPTS}/argocd.sh"
