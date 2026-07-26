# Part 3 — K3d and Argo CD

A **K3d** cluster (K3s running inside Docker containers, no virtual machine)
with **Argo CD** installed on it. Two namespaces: `argocd` for the controller
and `dev` for the application.

Argo CD watches a public GitHub repository and keeps the `dev` namespace in
sync with it. Changing the image tag in that repository is enough to redeploy
the application — that is the continuous deployment part.

| Item | Value |
|------|-------|
| Cluster name | `iot` |
| Namespaces | `argocd`, `dev` |
| Application | `wil42/playground`, port `8888`, tags `v1` / `v2` |
| Source repository | `github.com/ravazque/Inception-of-Things` |
| Watched path | `p3/confs/manifests/` |

## Requirements

Only **Docker** has to be installed and running. `install.sh` downloads
`kubectl`, `k3d` and the `argocd` CLI into `~/.local/bin` when they are
missing, so **no sudo and no package manager are needed**.

```bash
docker info          # must succeed; if not: sudo systemctl start docker
```

If it fails with a permission error, the user has to be in the `docker` group
(`sudo usermod -aG docker $USER`, then log out and back in).

## Start

```bash
./scripts/install.sh
```

The script creates the cluster from scratch, creates both namespaces, installs
Argo CD, applies the Application and waits for the first sync. At the end it
prints the Argo CD admin password and the port-forward commands.

## Test

```bash
kubectl get nodes                     # the k3d node, Ready
kubectl get ns                        # argocd and dev are there
kubectl get pods -n argocd            # Argo CD components Running
kubectl get pods -n dev               # playground Running
kubectl get application -n argocd     # Synced / Healthy
```

Reach the application — keep this terminal open:

```bash
kubectl -n dev port-forward svc/playground 8888:8888
```

and in another terminal:

```bash
curl http://localhost:8888
# {"status":"ok", "message": "v1"}
```

Argo CD web UI — keep this terminal open:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open `https://localhost:8080` (self-signed certificate, accept the warning),
user `admin`, password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

### Continuous deployment: v1 → v2

Change the image tag in this repository and push it:

```bash
sed -i 's|playground:v1|playground:v2|' p3/confs/manifests/deployment.yaml
git add p3/confs/manifests/deployment.yaml
git commit -m "playground: v2"
git push
```

Argo CD polls the repository every ~3 minutes. To apply the change right away:

```bash
kubectl -n argocd patch application playground --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

Then wait for the new pod and check the version again:

```bash
kubectl get pods -n dev -w              # wait until the new pod is Running
kubectl -n dev port-forward svc/playground 8888:8888
curl http://localhost:8888
# {"status":"ok", "message": "v2"}
```

Going back to `v1` works exactly the same way.

## Stop

Stops the containers but keeps the cluster and its data:

```bash
k3d cluster stop iot
k3d cluster start iot     # bring it back
```

## Destroy

```bash
k3d cluster delete iot
```
