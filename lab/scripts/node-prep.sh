#!/usr/bin/env bash
# Chuẩn bị node cho kubeadm: swap, kernel module, sysctl, containerd, kubeadm/kubelet/kubectl.
# Chỉ dùng sau khi đã tự làm tay 2 lần (Ngày 11–12).
set -euo pipefail
K8S_MINOR="${K8S_MINOR:-v1.34}"   # cài 1.34 để tuần 3 luyện upgrade lên 1.35
log() { printf '{"ts":"%s","host":"%s","level":"%s","msg":"%s"}\n' "$(date -Is)" "$(hostname)" "$1" "$2"; }
trap 'log error "failed at line $LINENO"' ERR
[[ $EUID -eq 0 ]] || { log error "run with sudo"; exit 1; }

log info "disable swap"
swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

log info "kernel modules + sysctl"
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
modprobe overlay && modprobe br_netfilter
cat > /etc/sysctl.d/99-k8s.conf <<EOT
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOT
sysctl --system >/dev/null

log info "containerd (SystemdCgroup)"
apt-get update -qq
apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg
install -d /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
grep -q 'SystemdCgroup = true' /etc/containerd/config.toml || { log error "SystemdCgroup not set"; exit 1; }
systemctl enable --now containerd && systemctl restart containerd

log info "kubeadm/kubelet/kubectl ${K8S_MINOR}"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
systemctl enable --now kubelet
log info "node ready for kubeadm"
