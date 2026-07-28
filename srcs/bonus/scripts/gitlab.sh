#!/bin/bash
# Deploy the local GitLab, create the public project Argo CD reads from and
# push the application manifests into it. Driven through the GitLab API, so
# there is no setup left to do in the web UI.
set -e

CLUSTER="${CLUSTER:-iot}"
NS="gitlab"
PROJECT="Inception-of-Things_ravazque"
IMAGE="gitlab/gitlab-ce:latest"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

# --- image -----------------------------------------------------------------
# Pulling on the host keeps the (large) image in the local Docker cache, so
# recreating the cluster later does not download it again.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "==> Pulling ${IMAGE} (this is a big image, be patient)"
  docker pull "${IMAGE}"
fi
echo "==> Importing the image into the k3d cluster"
k3d image import "${IMAGE}" -c "${CLUSTER}"

# --- deploy ----------------------------------------------------------------
echo "==> Deploying GitLab into the '${NS}' namespace"
kubectl apply -f "${CONFS}/gitlab.yaml"

echo "==> Waiting for GitLab to be ready (first boot: several minutes)"
kubectl -n "${NS}" rollout status deploy/gitlab --timeout=1800s

# --- port-forward ----------------------------------------------------------
# The API and the git push go through a temporary port-forward, so nothing has
# to be published on the host and no /etc/hosts entry is needed.
port_free() { ! (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
PORT=8081
while ! port_free "${PORT}"; do PORT=$((PORT + 1)); done

kubectl -n "${NS}" port-forward "svc/gitlab" "${PORT}:80" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT

API="http://127.0.0.1:${PORT}/api/v4"
echo "==> Waiting for the GitLab API on 127.0.0.1:${PORT}"
for _ in $(seq 1 60); do
  curl -sf "http://127.0.0.1:${PORT}/-/health" >/dev/null 2>&1 && break
  sleep 3
done

# --- API token -------------------------------------------------------------
# Reuse the token from a previous run when it is still valid, otherwise mint a
# new one with the Rails console and keep it in a Secret.
PAT="$(kubectl -n "${NS}" get secret gitlab-api-token \
  -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)"

if [ -z "${PAT}" ] || ! curl -sf -H "PRIVATE-TOKEN: ${PAT}" "${API}/user" >/dev/null 2>&1; then
  echo "==> Creating an API token for the root user"
  PAT="$(kubectl -n "${NS}" exec deploy/gitlab -- gitlab-rails runner "
    u = User.find_by_username('root')
    t = u.personal_access_tokens.create!(name: 'iot-bonus',
                                        scopes: ['api', 'write_repository'],
                                        expires_at: 300.days.from_now)
    puts \"TOKEN=#{t.token}\"
  " 2>/dev/null | sed -n 's/^TOKEN=//p' | tr -d '\r')"

  if [ -z "${PAT}" ]; then
    echo "ERROR: could not create a GitLab API token." >&2
    echo "       check 'kubectl -n ${NS} logs deploy/gitlab'" >&2
    exit 1
  fi

  kubectl -n "${NS}" create secret generic gitlab-api-token \
    --from-literal=token="${PAT}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# --- project ---------------------------------------------------------------
if curl -sf -H "PRIVATE-TOKEN: ${PAT}" "${API}/projects/root%2F${PROJECT}" >/dev/null 2>&1; then
  echo "==> Project root/${PROJECT} already exists"
else
  echo "==> Creating the public project root/${PROJECT}"
  curl -sf -X POST -H "PRIVATE-TOKEN: ${PAT}" "${API}/projects" \
    -d "name=${PROJECT}" \
    -d "path=${PROJECT}" \
    -d "visibility=public" >/dev/null
fi

# --- manifests -------------------------------------------------------------
# Pushed under manifests/, which is the path the Argo CD Application watches.
echo "==> Pushing the application manifests (v1) to GitLab"
WORK="$(mktemp -d)"
mkdir -p "${WORK}/manifests"
cp "${CONFS}/manifests/deployment.yaml" "${CONFS}/manifests/service.yaml" "${WORK}/manifests/"
git -C "${WORK}" init -q -b main
git -C "${WORK}" add .
git -C "${WORK}" -c user.name="IoT bonus" -c user.email="root@example.com" \
  commit -qm "IoT app manifests (v1)"
git -C "${WORK}" push -q --force \
  "http://oauth2:${PAT}@127.0.0.1:${PORT}/root/${PROJECT}.git" main
rm -rf "${WORK}"

# --- info ------------------------------------------------------------------
ROOT_PASS="$(kubectl -n "${NS}" get secret gitlab-root \
  -o jsonpath='{.data.password}' | base64 -d)"

echo
echo "GitLab is up."
echo "  repository (Argo CD source): http://gitlab.gitlab.svc.cluster.local/root/${PROJECT}.git (path: manifests)"
echo "  UI  : kubectl -n ${NS} port-forward svc/gitlab 8081:80  ->  http://localhost:8081"
echo "  user: root"
echo "  pass: ${ROOT_PASS}"
echo "  API token (also in secret gitlab-api-token): ${PAT}"
