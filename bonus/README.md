# Bonus — local GitLab

The same GitOps loop as Part 3, but the source repository is a **GitLab
instance running inside the cluster**, in its own `gitlab` namespace, instead
of GitHub.

Everything runs on the **host** with K3d, exactly like Part 3 — no virtual
machine is involved. The bonus reuses the Part 3 cluster when it already
exists, so it really is "Part 3 plus GitLab" and not a second lab.

| Item | Value |
|------|-------|
| Cluster name | `iot` (shared with Part 3) |
| Namespaces | `argocd`, `dev`, `gitlab` |
| GitLab | `gitlab/gitlab-ce:latest`, one pod, plain HTTP |
| Repository | `root/ravazque-iot`, public, watched path `manifests/` |
| Application | `wil42/playground`, port `8888`, tags `v1` / `v2` |

The whole setup is automated through the GitLab API: the scripts create the
root token, create the public project and push the manifests. There is no
click-through setup to do in the web UI.

## Requirements

Docker running, and roughly **8 GB of free RAM**. GitLab CE is a heavy image
(~3.5 GB to download) and its first boot runs the full database migration, so
expect **10 to 20 minutes** before it answers. Close the other parts first:

```bash
cd ../p1 && vagrant destroy -f
cd ../p2 && vagrant destroy -f
cd ../bonus
```

As in Part 3, `kubectl`, `k3d` and `argocd` are downloaded into
`~/.local/bin` if missing — **no sudo needed**.

## Start

```bash
./scripts/install.sh
```

What it does, in order:

1. Checks Docker and warns if the host has little RAM.
2. Creates (or reuses) the `iot` K3d cluster and the three namespaces.
3. `scripts/gitlab.sh` — pulls the GitLab image, imports it into the cluster,
   deploys it, waits for it to be healthy, creates an API token, creates the
   public project `root/ravazque-iot` and pushes `confs/manifests/` into it.
4. `scripts/argocd.sh` — installs Argo CD (or reuses it) and applies the
   Application pointing at the local GitLab.

At the end it prints the GitLab root password, the Argo CD admin password and
the port-forward commands.

## Test

```bash
kubectl get ns                     # argocd, dev, gitlab
kubectl -n gitlab get pods         # gitlab-... Running 1/1
kubectl -n dev get pods            # playground Running
kubectl get application -n argocd  # Synced / Healthy
```

Confirm that Argo CD really is reading from GitLab and not from GitHub:

```bash
kubectl -n argocd get application playground \
  -o jsonpath='{.spec.source.repoURL}{"\n"}'
# http://gitlab.gitlab.svc.cluster.local/root/ravazque-iot.git
```

GitLab web UI — keep this terminal open:

```bash
kubectl -n gitlab port-forward svc/gitlab 8081:80
```

Open `http://localhost:8081`, user `root`, password:

```bash
kubectl -n gitlab get secret gitlab-root \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

The application:

```bash
kubectl -n dev port-forward svc/playground 8888:8888
curl http://localhost:8888
# {"status":"ok", "message": "v1"}
```

### Continuous deployment from the local GitLab: v1 → v2

Clone the project from GitLab, change the tag and push. The API token created
by the install script is stored in a Secret:

```bash
TOKEN=$(kubectl -n gitlab get secret gitlab-api-token \
  -o jsonpath='{.data.token}' | base64 -d)

kubectl -n gitlab port-forward svc/gitlab 8081:80 &

git clone "http://oauth2:${TOKEN}@127.0.0.1:8081/root/ravazque-iot.git" /tmp/iot-bonus
cd /tmp/iot-bonus
sed -i 's|playground:v1|playground:v2|' manifests/deployment.yaml
git commit -am "playground: v2"
git push
```

Argo CD polls every ~3 minutes; to apply it immediately:

```bash
kubectl -n argocd patch application playground --type merge \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}'

kubectl get pods -n dev -w
kubectl -n dev port-forward svc/playground 8888:8888
curl http://localhost:8888
# {"status":"ok", "message": "v2"}
```

The same edit can be done from the GitLab web UI, which shows the loop more
clearly during a demo.

## Stop

```bash
k3d cluster stop iot
k3d cluster start iot     # GitLab needs a few minutes to be healthy again
```

## Destroy

```bash
k3d cluster delete iot
```

The GitLab image stays in the local Docker cache, so a later run does not
download it again. To free that space too:

```bash
docker rmi gitlab/gitlab-ce:latest
```
