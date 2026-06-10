*This project has been created as part of the 42 curriculum by ravazque and [partner].*

---

## Description

Inception of Things (IoT) is a system administration / DevOps project: a journey into **Kubernetes** that goes from provisioning virtual machines to a complete **GitOps** workflow, using Vagrant, K3s, K3d and Argo CD.

The repository is organized in the three parts the subject requires:

- **`p1/`** — two Vagrant VMs on a private network with fixed IPs: a K3s **server** (controller) and a K3s **agent** (worker), verified with `kubectl get nodes`.
- **`p2/`** — a single K3s server VM hosting **three web applications** behind an Ingress that routes by Host header (`app1.com`, `app2.com`, `app3.com` on the same IP), one of them replicated three times.
- **`p3/`** — a **K3d** cluster running inside Docker with **Argo CD** installed: an application is deployed from a Git repository and kept in sync automatically — changing the image tag in Git redeploys it with no manual action.
- **`bonus/`** — a local **GitLab** instance integrated into the same cluster, closing the GitOps loop entirely on-premise.

Every configuration file lives in the repository, and the whole infrastructure can be brought up from scratch with `vagrant up` and the provided scripts.
