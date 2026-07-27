# Part 2 — K3s and three simple applications

One Vagrant virtual machine running a single-node K3s server that hosts **three
web applications** behind a single **Ingress**. The Ingress decides which
application answers by looking at the `Host` header of the request:

| Host header | Application | Replicas |
|-------------|-------------|----------|
| `app1.com`  | app1        | 1        |
| `app2.com`  | app2        | 3        |
| anything else | app3 (default backend) | 1 |

All three are nginx containers serving a small page that also prints the pod
name, which makes the load balancing across `app2`'s replicas visible.

## Machine

| Name        | IP               | Role                     | Resources       |
|-------------|------------------|--------------------------|-----------------|
| `ravazqueS` | `192.168.56.110` | K3s server (single node) | 1 CPU / 1024 MB |

Guest OS: **Ubuntu 22.04** (`generic/ubuntu2204`).

## Requirements

Vagrant plus one provider. The `Vagrantfile` declares both:

| Host | Command |
|------|---------|
| Linux with KVM | `vagrant up --provider=libvirt` (needs the `vagrant-libvirt` plugin) |
| Ubuntu with VirtualBox | `vagrant up --provider=virtualbox` |

> `192.168.56.0/24` is inside the host-only range VirtualBox allows by default,
> so no extra configuration is needed. Only on a locked-down host would an
> administrator have to add `* 192.168.56.0/24` to `/etc/vbox/networks.conf`.

## Start

```bash
vagrant up --provider=libvirt      # KVM
vagrant up --provider=virtualbox   # VirtualBox
```

The provisioning uploads `confs/` into the machine, installs K3s, applies the
manifests and waits for every rollout — including Traefik, the Ingress
controller K3s installs on first boot.

## Test

From the **host**, no DNS needed — `curl` sets the header itself:

```bash
curl -H "Host: app1.com" http://192.168.56.110     # Hello from app1
curl -H "Host: app2.com" http://192.168.56.110     # Hello from app2
curl -H "Host: other"    http://192.168.56.110     # Hello from app3 (default)
```

Repeat the `app2.com` request a few times: the pod name in the reply changes,
which shows the Service balancing across the three replicas.

```bash
for i in 1 2 3 4 5 6; do curl -s -H "Host: app2.com" http://192.168.56.110 | grep pod; done
```

Inside the machine:

```bash
vagrant ssh ravazqueS -c "kubectl get deploy,svc,ingress"   # app2 must be 3/3
vagrant ssh ravazqueS -c "kubectl get pods -o wide"
vagrant ssh ravazqueS -c "kubectl describe ingress apps"    # the routing rules
```

Optional browser test — add this line to the host `/etc/hosts`:

```
192.168.56.110 app1.com app2.com app3.com
```

then open `http://app1.com`, `http://app2.com` and `http://192.168.56.110`.

## Stop

Shuts the machine down but keeps it on disk:

```bash
vagrant halt
```

## Re-Start

```bash
vagrant up        # bring it back, no reprovisioning
```

## Destroy

```bash
vagrant destroy -f
```
