# Inception of Things

## 📖 About

"Inception of Things" (IoT) is a System Administration / DevOps project: a
hands-on introduction to **Kubernetes**. It goes from
provisioning reproducible virtual machines with **Vagrant** all the way to a
complete **GitOps** pipeline, using **K3s**, **K3d** and **Argo CD**, plus a
local **GitLab** in the bonus.

The project is split into three mandatory parts and one bonus, each in its own
folder at the root of the repository (`p1`, `p2`, `p3`, `bonus`). Every part is
self-contained and can be brought up from scratch with a single command.
Parts 1 and 2 run in virtual machines: the guest OS is **Ubuntu 22.04** and the
`Vagrantfile`s work with both the **libvirt/KVM** and **VirtualBox** providers.
Part 3 and the bonus need no virtual machine at all — they run on Docker, and
their scripts install every missing tool into `~/.local/bin`, so **no sudo is
required**.

## 🎯 Objectives

- Provisioning reproducible virtual machines from a `Vagrantfile`
- Building a multi-node **K3s** cluster (server / agent) over a private network
- Understanding Kubernetes primitives: pods, deployments, services, replicas
- Exposing applications through an **Ingress** that routes by Host header
- Running **K3d** (K3s inside Docker) without any virtual machine
- Installing and operating **Argo CD** as a GitOps controller
- Implementing continuous deployment: a Git push redeploys the cluster
- Adding a self-hosted **GitLab** and closing the GitOps loop on-premise (bonus)

## 📋 Function Overview

<details>
<summary><strong>Inception of Things — parts breakdown</strong></summary>

<br>

| Part | Feature | Description |
|------|---------|-------------|
| **p1** | Two-node cluster | Two Vagrant VMs on a private network: K3s `server` + `agent` |
| **p1** | Fixed IPs | `ravazqueS` → `192.168.56.110`, `ravazqueSW` → `192.168.56.111` |
| **p1** | Pre-shared token join | Agent joins the server without copying any node-token file |
| **p1** | Passwordless SSH | `vagrant ssh` into either machine, no password |
| **p2** | Three web apps | Three nginx apps served from one single-node K3s server |
| **p2** | Host-based routing | `app1.com` → app1, `app2.com` → app2, anything else → app3 |
| **p2** | Replicas | app2 runs with **3 replicas** behind one Service |
| **p2** | Ingress | Traefik Ingress bundled with K3s, one rule per host + a catch-all |
| **p3** | K3d cluster | K3s running inside Docker containers, no VM |
| **p3** | Argo CD | GitOps controller installed in its own `argocd` namespace |
| **p3** | Namespaces | `argocd` (controller) and `dev` (the deployed application) |
| **p3** | Continuous deployment | App synced from a public GitHub repo; tag change → auto redeploy |
| **p3** | Versioned app | `wil42/playground` on port 8888, tags `v1` / `v2` |
| **bonus** | Local GitLab | GitLab CE running in the cluster, in a dedicated `gitlab` namespace |
| **bonus** | Automated setup | Root token, public project and manifests created through the GitLab API |
| **bonus** | On-prem GitOps | Argo CD sources the app from the local GitLab instead of GitHub |

<br>

</details>

<details>
<summary><strong>Usage Example & Testing</strong></summary>

### Part 1 — K3s and Vagrant

```bash
cd p1
vagrant up --provider=libvirt                       # or --provider=virtualbox
vagrant ssh ravazqueS -c "kubectl get nodes -o wide"   # both nodes Ready
vagrant destroy -f
```

### Part 2 — three apps behind an Ingress

```bash
cd p2
vagrant up --provider=libvirt
curl -H "Host: app1.com" http://192.168.56.110      # Hello from app1
curl -H "Host: app2.com" http://192.168.56.110      # Hello from app2
curl -H "Host: other"    http://192.168.56.110      # Hello from app3 (default)
vagrant ssh ravazqueS -c "kubectl get deploy"       # app2 -> 3/3
vagrant destroy -f
```

### Part 3 — K3d + Argo CD

```bash
cd p3
./scripts/install.sh                # k3d cluster + Argo CD + Application
kubectl get ns                      # argocd + dev
kubectl get application -n argocd   # Synced / Healthy
kubectl -n dev port-forward svc/playground 8888:8888 &
curl http://localhost:8888          # {"status":"ok", "message": "v1"}
# bump the tag in p3/confs/manifests/deployment.yaml and push
# -> Argo CD redeploys -> curl returns v2
k3d cluster delete iot
```

### Bonus — local GitLab

```bash
# free memory first: destroy the p1/p2 machines
cd bonus
./scripts/install.sh                # heavy: GitLab CE is a ~3.5 GB image
kubectl get ns                      # argocd + dev + gitlab
kubectl -n gitlab get pods          # gitlab Running 1/1
kubectl -n dev port-forward svc/playground 8888:8888 &
curl http://localhost:8888          # {"status":"ok", "message": "v1"}
k3d cluster delete iot
```

Each folder has a `README.md` with the full start / test / stop / destroy flow.

<br>

</details>

## 🚀 Installation & Structure

<details>
<summary><strong>📥 Setup & Usage</strong></summary>

<br>

### Host requirements

| Tool | Needed for | Installed by hand? |
|------|------------|--------------------|
| Vagrant + a provider | Parts 1 and 2 | Yes — libvirt/KVM or VirtualBox |
| Docker | Part 3 and the bonus | Yes — the daemon must be running |
| kubectl, k3d, argocd | Part 3 and the bonus | No — the scripts drop them into `~/.local/bin` |
| git | Pushing the tag change in Part 3 | Usually already present |

### Provider selection

```bash
# Linux (native KVM):
vagrant up --provider=libvirt
# Ubuntu hosts with VirtualBox:
vagrant up --provider=virtualbox
# Or make it the default:
export VAGRANT_DEFAULT_PROVIDER=libvirt
```

### Day-to-day (per part folder)

```bash
# Parts 1 and 2 (Vagrant):
vagrant up --provider=libvirt   # start
vagrant halt                    # stop
vagrant destroy -f              # remove
vagrant ssh <machine>           # log in

# Part 3 and bonus (host, Docker only):
./scripts/install.sh            # create everything
k3d cluster stop iot            # stop
k3d cluster delete iot          # remove
```

<br>

</details>

<details>
<summary><strong>📁 Project Structure</strong></summary>

<br>

```
Inception_of_Things/
│
├── README.md
├── .gitignore
│
├── docs/
│   └── README.md                   # Condensed project documentation
│
├── p1/                             # Part 1 — K3s + Vagrant (2 nodes)
│   ├── README.md                   # start / test / stop / destroy
│   ├── Vagrantfile                 # ravazqueS (.110) + ravazqueSW (.111)
│   └── scripts/
│       ├── server.sh               # install K3s in server (control-plane) mode
│       └── worker.sh               # install K3s agent and join the server
│
├── p2/                             # Part 2 — K3s + 3 apps + Ingress
│   ├── README.md                   # start / test / stop / destroy
│   ├── Vagrantfile                 # ravazqueS (.110)
│   ├── scripts/
│   │   └── setup.sh                # K3s server + apply the manifests
│   └── confs/
│       ├── app1.yaml               # app1 (1 replica)
│       ├── app2.yaml               # app2 (3 replicas)
│       ├── app3.yaml               # app3 (default backend)
│       └── ingress.yaml            # Host-based routing (Traefik)
│
├── p3/                             # Part 3 — K3d + Argo CD (GitOps)
│   ├── README.md                   # start / test / v1→v2 / stop / destroy
│   ├── scripts/
│   │   └── install.sh              # k3d cluster + namespaces + Argo CD + Application
│   └── confs/
│       ├── application.yaml        # Argo CD Application (repo, path, destination)
│       └── manifests/              # what Argo CD deploys (the watched path)
│           ├── deployment.yaml     # wil42/playground — the image tag lives here
│           └── service.yaml        # port 8888 inside the cluster
│
└── bonus/                          # Bonus — local GitLab
    ├── README.md                   # start / test / v1→v2 / stop / destroy
    ├── scripts/
    │   ├── install.sh              # tools + k3d cluster + namespaces
    │   ├── gitlab.sh               # deploy GitLab, create the project, push manifests
    │   └── argocd.sh               # install Argo CD + Application (GitLab source)
    └── confs/
        ├── gitlab.yaml             # root Secret + PVCs + Deployment + Service (GitLab CE)
        ├── application.yaml        # Argo CD Application (local GitLab source)
        └── manifests/              # pushed into the GitLab project
            ├── deployment.yaml
            └── service.yaml
```

`p1` deploys no application, so it carries no `confs/`; the bonus runs on the
host with K3d, so it carries no `Vagrantfile`.

<br>

</details>

<details>
<summary><strong>🧱 Infrastructure Overview</strong></summary>

<br>

### Part 1 — two-node K3s

```
[ ravazqueS 192.168.56.110 ]  K3s server (control-plane)
          ▲  private network (192.168.56.0/24)
          │  agent joins with a pre-shared token
[ ravazqueSW 192.168.56.111 ] K3s agent (worker)
```

### Part 2 — Ingress routing

```
curl -H "Host: appN.com" ──> [ Traefik Ingress @ 192.168.56.110 ]
        app1.com ─> app1 (1)     app2.com ─> app2 (3)     * ─> app3 (1)
```

### Part 3 / Bonus — GitOps

```
[ Git repo ] ──sync──> [ Argo CD @ K3d ] ──deploy──> [ app in dev namespace ]
   push v1/v2                                            curl :8888 -> vN
   (GitHub in Part 3, local GitLab in the bonus)
```

<br>

</details>

## 💡 Key Learning Outcomes

- **Infrastructure as Code**: reproducible VMs and clusters from files only
- **Kubernetes fundamentals**: nodes, deployments, services, replicas, ingress
- **K3s vs K3d**: when to use a lightweight distro on VMs vs inside Docker
- **Networking**: private networks, fixed IPs, provider-agnostic NIC detection,
  flannel over the right interface, Host-header routing through Traefik
- **GitOps**: Git as the single source of truth, Argo CD reconciliation,
  automated sync and continuous deployment on image-tag changes
- **Self-hosting**: running a heavy stateful application (GitLab) on a cluster
  with persistent volumes, and driving it from its REST API

## ⚙️ Technical Specifications

- **Provisioning**: Vagrant, dual provider (libvirt/KVM + VirtualBox)
- **Guest OS**: Ubuntu 22.04 (`generic/ubuntu2204`, multi-provider box)
- **Kubernetes**: K3s (Parts 1–2, in VMs), K3d (Part 3 + bonus, in Docker)
- **Ingress**: Traefik (bundled with K3s/K3d)
- **GitOps**: Argo CD, auto-sync with prune + self-heal
- **App**: `wil42/playground` (port 8888), tags `v1` / `v2`
- **Bonus**: `gitlab/gitlab-ce:latest` in the `gitlab` namespace, plain HTTP,
  set up through the GitLab REST API
- **Networks**: private `192.168.56.0/24`; `.110` / `.111` (p1), `.110` (p2)
- **Resources**: 1 CPU / 1024 MB per p1/p2 node; ~8 GB of free RAM for the bonus

## 🔧 Requirements

- A Linux host (recommended for libvirt/KVM; VirtualBox also works)
- Vagrant with the **vagrant-libvirt** plugin, or VirtualBox — Parts 1 and 2
- Docker Engine, daemon running — Part 3 and the bonus
- `git`, to push the tag change that drives the continuous deployment

`kubectl`, `k3d` and the `argocd` CLI do **not** have to be installed: the
Part 3 and bonus scripts download them into `~/.local/bin` when missing, which
makes both parts work on a machine without sudo.

---

> [!NOTE]
> Inception of Things is a minimal but complete introduction to Kubernetes:
> the same application is taken from a hand-built two-node cluster, through a
> single-node Ingress setup, all the way to a fully automated GitOps pipeline
> driven by Git — first from GitHub, then from a self-hosted GitLab.
