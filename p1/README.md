# Part 1 — K3s and Vagrant

Two Vagrant virtual machines on a private network forming a K3s cluster: one
**server** (control-plane) and one **agent** (worker). The goal is simple —
`kubectl get nodes` on the server must list both machines as `Ready`.

## Machines

| Name         | IP               | Role                       | Resources        |
|--------------|------------------|----------------------------|------------------|
| `ravazqueS`  | `192.168.56.110` | K3s server (control-plane) | 1 CPU / 1024 MB  |
| `ravazqueSW` | `192.168.56.111` | K3s agent (worker)         | 1 CPU / 1024 MB  |

Guest OS: **Ubuntu 22.04** (`generic/ubuntu2204`). The agent joins the server
with a token shared through the `Vagrantfile`, so no token file has to be
copied between machines. This part has no Kubernetes manifests: the whole
cluster is built by the two provisioning scripts.

## Requirements

Vagrant plus one provider. The `Vagrantfile` declares both, so the same file
works on either machine:

| Host | Command |
|------|---------|
| Linux with KVM | `vagrant up --provider=libvirt` (needs the `vagrant-libvirt` plugin) |
| Ubuntu with VirtualBox | `vagrant up --provider=virtualbox` |

You can also set it once with `export VAGRANT_DEFAULT_PROVIDER=libvirt` and
then just run `vagrant up`.

> `192.168.56.0/24` is inside the host-only range VirtualBox allows by default,
> so no extra configuration is needed. Only on a locked-down host would an
> administrator have to add `* 192.168.56.0/24` to `/etc/vbox/networks.conf`.

## Start

```bash
vagrant up --provider=libvirt
```

```bash
vagrant up --provider=virtualbox
```

The first run downloads the box and takes a few minutes. Later runs are much
faster.

## Test

```bash
# Both nodes Ready, one control-plane and one worker:
vagrant ssh ravazqueS -c "kubectl get nodes -o wide"

# The private IPs are the ones the subject asks for:
vagrant ssh ravazqueS  -c "ip -4 addr show | grep 192.168.56"
vagrant ssh ravazqueSW -c "ip -4 addr show | grep 192.168.56"

# Passwordless SSH into either machine:
vagrant ssh ravazqueSW
```

Expected output of the first command:

```
NAME         STATUS   ROLES           AGE   VERSION        INTERNAL-IP
ravazques    Ready    control-plane   2m    v1.xx.x+k3s1   192.168.56.110
ravazquesw   Ready    <none>          1m    v1.xx.x+k3s1   192.168.56.111
```

Node names appear in lowercase because Kubernetes normalises them to DNS
labels. The machine hostnames themselves keep the capital letters — check with
`vagrant ssh ravazqueS -c hostname`. A worker showing `<none>` under ROLES is
also normal: only the control-plane carries a role label.

Both services can be inspected from inside the machines:

```bash
vagrant ssh ravazqueS  -c "systemctl status k3s --no-pager"
vagrant ssh ravazqueSW -c "systemctl status k3s-agent --no-pager"
```

## Stop

Shuts the machines down but keeps them on disk:

```bash
vagrant halt
vagrant up        # bring them back, no reprovisioning
```

## Destroy

Removes the machines completely:

```bash
vagrant destroy -f
```
