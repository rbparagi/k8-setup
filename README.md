# Kubernetes HA Cluster with Keepalived + HAProxy (Ansible Automated)

---

## 🖥️ OS Image Details
- **AMI ID:** `ami-0219bfb6c89d10de5`
- **OS:** CentOS Stream 9 (Rocky Linux-compatible)
- **Region:** `ap-south-1`

---

## 📦 Setup Overview
This project automates the setup of a Highly Available Kubernetes control plane using:
- **Keepalived** for VIP failover
- **HAProxy** for load balancing to kube-apiservers
- **Ansible** to automate the complete setup

---

## ✅ Completed Components
- [x] VIP setup using Keepalived
- [x] HAProxy config to forward traffic to `kube-apiserver`
- [x] Kubernetes pre-requisites installed (containerd, kernel modules, sysctl)
- [x] SELinux disabled (🔴 was the key issue!)
- [x] Kubeadm init with HA endpoint `11.0.1.240:8443`
- [x] HAProxy listens on `:8443` to forward to ports `:6443` of each master

---

## 📁 Folder Structure
```bash
k8s-ha-setup/
├── inventory.ini              # Ansible inventory with master IPs
├── k8s-setup.yaml             # Ansible Playbook (prereqs + K8s + HAProxy + Keepalived)
├── templates/
│   └── keepalived.conf.j2     # Dynamic Keepalived template with role priorities
├── README.md                  # This documentation
```

---

## 📋 Step-by-step Setup

### 1. Create 3 EC2 Instances with below Private IPs:
| Hostname       | Private IP  |
|----------------|-------------|
| k8s-master-1   | 11.0.1.79   |
| k8s-master-2   | 11.0.1.36   |
| k8s-master-3   | 11.0.1.223  |


### 2. SSH Access
Ensure all nodes are reachable via SSH using:
```bash
ssh -i /tmp/master-aws-key.pem rocky@11.0.1.79
```

### 3. Prepare Inventory File
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
```

### 4. Run Playbook
```bash
ansible-playbook -i inventory.ini k8s-setup.yaml
```

### 5. Init First Master
```bash
sudo kubeadm init --control-plane-endpoint "11.0.1.240:8443" --upload-certs
```

### 6. Setup Kubeconfig
```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## ✅ Validation Steps

### 🔁 HAProxy Check
```bash
curl -k https://localhost:8443/livez
curl -k https://11.0.1.240:8443/livez
```

### 🔁 VIP Check
```bash
ip a | grep 11.0.1.240
ping 11.0.1.240
```
Ensure only one master holds the VIP.

### 🔁 kube-apiserver Check
```bash
crictl ps -a | grep kube-apiserver
sudo ss -ltnp | grep 6443
```

---

## ⚠️ Key Issue Faced
- SELinux **not disabled** caused `Permission denied` on HAProxy → kube-apiserver TCP connections
- ✅ Fixed by adding SELinux disable in playbook:
```yaml
- name: Disable SELinux permanently
  copy:
    dest: /etc/selinux/config
    content: |
      SELINUX=disabled
      SELINUXTYPE=targeted
- name: Disable SELinux now
  command: setenforce 0
  ignore_errors: true
```

---

## 🚀 Next Steps
- Automate joining the 2nd and 3rd master using `kubeadm join`
- Add worker node setup
- Add CNI plugin (like Calico)
- Enable monitoring with Prometheus + Grafana

---

> Last Updated: {{ date }}
