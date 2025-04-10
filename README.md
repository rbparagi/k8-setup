# Kubernetes HA Setup using Ansible

This repo automates the setup of a Highly Available (HA) Kubernetes Control Plane using:
- Keepalived (VIP)
- HAProxy (Load Balancer)
- Containerd (Runtime)
- kubeadm (K8s Install)

## 🔧 Prerequisites

- 3+ Linux nodes (Tested on Rocky Linux)
- Passwordless SSH access (via PEM key)
- Ansible installed
- Python 3.6+ with `kubespray-venv` (recommended)

## 🌐 Inventory Setup

Edit `inventory.ini` with your master nodes:

```ini
[masters]
k8s-master-1 ansible_host=11.0.1.79 hostname=k8s-master-1 priority=101
k8s-master-2 ansible_host=11.0.1.36 hostname=k8s-master-2 priority=100
k8s-master-3 ansible_host=11.0.1.223 hostname=k8s-master-3 priority=99

[all:vars]
ansible_user=rocky
ansible_ssh_private_key_file=/tmp/master-aws-key.pem
vip=11.0.1.240
interface=eth0
