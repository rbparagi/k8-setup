# Kubernetes HA Setup with Keepalived and HAProxy (Rocky Linux)

This repository contains a complete setup for provisioning a production-grade **Highly Available (HA)** Kubernetes control plane using:

- **Keepalived** for Virtual IP (VIP) failover
- **HAProxy** for load balancing kube-apiserver
- **Kubeadm** to bootstrap the Kubernetes cluster

> ✅ This setup was validated and debugged end-to-end, and contains notes on pitfalls (like SELinux) and validation steps.

---

## 🌐 Cluster Details

| Component    | Value                |
|--------------|----------------------|
| VIP          | `11.0.1.240`         |
| HAProxy Port | `8443`               |
| Nodes        | 3 masters (no worker)|
| OS           | Rocky Linux 9        |
| Container Runtime | containerd     |
| Kubernetes Version | v1.30.x (YUM repo) |

---

## 📁 Folder Structure

```
├── inventory.ini                  # Ansible inventory file
├── k8s-setup.yaml                # Main Ansible playbook
├── templates/
│   └── keepalived.conf.j2        # Keepalived configuration template
├── files/
│   └── master-aws-key.pem        # SSH key (not in repo)
└── README.md                     # This file
```

---

## ⚙️ Prerequisites Setup (Automated via Ansible)

### System Configuration:
- Set hostnames from Ansible inventory
- Add all master node IPs to `/etc/hosts`
- Disable swap
- Disable SELinux (🔴 This was the main culprit during validation)
- Kernel modules & sysctl for Kubernetes networking

### Package Install:
- `curl`, `wget`, `vim`, `git`, `net-tools`, `socat`, `iproute-tc`, etc.
- Docker repo for installing `containerd`
- Configure `containerd` to use `SystemdCgroup`

### Kubernetes Repo:
- Uses official repo from `pkgs.k8s.io` for v1.30
- Installs `kubelet`, `kubeadm`, `kubectl`

### HA Configuration:
- Install and configure `haproxy` to bind to `*:8443`
- Setup `keepalived` with proper priorities and VIP configuration

---

## 🧪 Validation Checklist

### 🔁 Virtual IP Failover (Keepalived)
- Checked with: `ip a | grep 11.0.1.240` (only one node should hold it)
- Manual restart of keepalived to simulate failover
- Validated gratuitous ARP broadcast with `journalctl -u keepalived -f`

### ⚖️ HAProxy Connectivity
- Verified HAProxy binds to `8443`: `ss -ltnp | grep 8443`
- Checked API forwarding: `curl -k https://localhost:6443/livez`
- Then validated via HAProxy: `curl -k https://11.0.1.240:8443/livez`
- `nc -zv 11.0.1.240 8443` from all masters to confirm reachability

### 🧵 kubeadm Init Success
- Bootstrap cluster with VIP as control-plane endpoint:
  ```bash
  sudo kubeadm init \
    --control-plane-endpoint "11.0.1.240:8443" \
    --upload-certs
  ```
- Watch pods spin up in `/etc/kubernetes/manifests`

### ✅ Final Kubernetes Health
- `kubectl get nodes` from master
- `curl -k https://11.0.1.240:8443/livez` returns `ok`
- HAProxy logs show backends are healthy (no Layer4 failures)

---

## 🚨 Gotchas (Lessons Learned)

| Issue | Root Cause | Fix |
|-------|------------|-----|
| `curl -k https://VIP:PORT` fails | SELinux blocking HAProxy | ✅ Disable SELinux
| `kubectl` times out | HAProxy config error or wrong port | ✅ Fixed port to `8443`, used `tcp-check`
| HAProxy healthcheck fails | Wrong option (`check` instead of `tcp-check`) | ✅ Use `option tcp-check` in config

---

## 🚀 Next Steps

- [ ] Add worker node automation
- [ ] Join remaining masters via `kubeadm join --control-plane`
- [ ] Push this repo to GitHub with `README.md` and `.gitignore`

---

## 💬 Credits
This setup and battle-hardened troubleshooting was done by Ravi with help from ChatGPT 🙂. Kudos for sticking through hours of debugging to get this done right!
