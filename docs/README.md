*Created by ravazque, luferna3 and jorbarro.*

---

# Inception of Things

Inception of Things (IoT) is a System Administration / DevOps project: a guided
journey into **Kubernetes**, from provisioning virtual machines with
**Vagrant** to a full **GitOps** workflow, using **K3s**, **K3d** and
**Argo CD**, with a self-hosted **GitLab** in the bonus.

## Layout

```
.
├── p1/      Vagrantfile · scripts/            # K3s + Vagrant (2 nodes)
├── p2/      Vagrantfile · scripts/ · confs/   # K3s + 3 apps + Ingress
├── p3/      scripts/ · confs/manifests/       # K3d + Argo CD (GitOps)
└── bonus/   scripts/ · confs/manifests/       # K3d + Argo CD + local GitLab
```

Each part is self-contained and ships its own README with the exact commands to
**start, test, stop and destroy** it:

- [`p1/README.md`](../p1/README.md) — Part 1: K3s + Vagrant (two nodes)
- [`p2/README.md`](../p2/README.md) — Part 2: K3s + three apps + Ingress
- [`p3/README.md`](../p3/README.md) — Part 3: K3d + Argo CD (GitOps)
- [`bonus/README.md`](../bonus/README.md) — Bonus: local GitLab

## Stack

| Tool     | Role                                                          |
|----------|---------------------------------------------------------------|
| Vagrant  | Reproducible VMs described in a `Vagrantfile`                  |
| libvirt / VirtualBox | The hypervisor Vagrant drives (the *provider*)      |
| K3s      | Lightweight Kubernetes, one binary: `server` / `agent` modes   |
| K3d      | K3s running inside Docker containers, no VM needed             |
| Docker   | Container runtime K3d relies on                                |
| kubectl  | CLI to inspect the cluster and apply manifests                 |
| Traefik  | Ingress controller bundled with K3s, routes by Host header     |
| Argo CD  | GitOps controller: keeps the cluster in sync with a repository |
| GitLab   | Self-hosted Git server used as the source in the bonus         |

The VMs run **Ubuntu 22.04** (`generic/ubuntu2204`), a box published for both
**libvirt** and **VirtualBox** — pick one with `--provider=`. Parts 1 and 2 use
Vagrant; Part 3 and the bonus run on the host with Docker and no VM at all.

## Parts at a glance

| Part  | What it sets up                                       | Machines                              |
|-------|-------------------------------------------------------|---------------------------------------|
| p1    | K3s server + agent across two VMs                     | `ravazqueS` .110 · `ravazqueSW` .111  |
| p2    | One K3s node, 3 apps, Ingress routing by Host header  | `ravazqueS` .110                      |
| p3    | K3d + Argo CD, app auto-deployed from GitHub (v1/v2)  | none (Docker on the host)             |
| bonus | Same GitOps loop, source repo is an in-cluster GitLab | none (Docker on the host)             |

## How each part works

**Part 1.** Two VMs on the private network `192.168.56.0/24`. The first one
installs K3s in `server` mode (control-plane), the second one in `agent` mode.
Both scripts resolve the network interface from the IP address, so the same
code works whatever the provider names the NIC (`eth1`, `enp0s8`, …). The agent
authenticates with a token shared through the `Vagrantfile`, which avoids
copying the auto-generated node token between machines.

**Part 2.** One K3s server. Three nginx applications, each with its own
ConfigMap (the page it serves), Deployment and Service; `app2` runs with three
replicas. A single Ingress routes on the `Host` header: `app1.com` to app1,
`app2.com` to app2, and a rule with no host at all acts as the default backend
pointing to app3.

**Part 3.** A K3d cluster (Kubernetes inside Docker) with two namespaces:
`argocd` for the controller and `dev` for the application. An Argo CD
`Application` object points at a public GitHub repository and a path inside it;
Argo CD deploys what it finds there and re-checks periodically. Changing the
image tag in Git and pushing is enough to redeploy the app.

**Bonus.** The same cluster, plus a `gitlab` namespace running GitLab CE. The
install scripts create a root API token, create a public project and push the
manifests into it, then re-point the Argo CD `Application` at the in-cluster
GitLab URL. The GitOps loop then runs entirely on-premise.

## Key requirements met

- **Part 1** — two VMs, fixed private IPs `.110`/`.111`, hostnames ending in
  `S` and `SW`, passwordless SSH, K3s in server and agent mode, `kubectl`
  available on the server.
- **Part 2** — single K3s server, three web applications, Ingress routing by
  `Host` header, `app2` with three replicas, `app3` as the default backend.
- **Part 3** — K3d, Argo CD, namespaces `argocd` and `dev`, continuous
  deployment from a public GitHub repository, application available in two
  versions (`v1` / `v2`).
- **Bonus** — GitLab running locally in a dedicated `gitlab` namespace, with
  everything from Part 3 working against it.

## References

Project tools:

- Kubernetes documentation — <https://kubernetes.io/docs/home/>
- Kubernetes concepts: Deployment, Service, Ingress —
  <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/>,
  <https://kubernetes.io/docs/concepts/services-networking/service/>,
  <https://kubernetes.io/docs/concepts/services-networking/ingress/>
- K3s — <https://docs.k3s.io/>
- K3d — <https://k3d.io/>
- Vagrant — <https://developer.hashicorp.com/vagrant/docs>
- vagrant-libvirt provider — <https://vagrant-libvirt.github.io/vagrant-libvirt/>
- Docker Engine — <https://docs.docker.com/engine/>
- Traefik Kubernetes Ingress — <https://doc.traefik.io/traefik/providers/kubernetes-ingress/>
- Argo CD — <https://argo-cd.readthedocs.io/en/stable/>
- Argo CD `Application` specification —
  <https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml>
- GitLab CE Docker image — <https://docs.gitlab.com/ee/install/docker.html>
- GitLab REST API — <https://docs.gitlab.com/ee/api/rest/>

Application used in Part 3 and the bonus:

- `wil42/playground` on Docker Hub — <https://hub.docker.com/r/wil42/playground>
  (port `8888`, tags `v1` and `v2`)
