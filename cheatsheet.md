# CKA cheatsheet

Cập nhật lần cuối: Ngày 5 (13/10/2026). Mỗi mục ghi ngày học để biết mục nào cần ôn lại.

## 0. Đầu giờ thi / đầu buổi lab

```bash
alias k=kubectl                                   # đề đã có sẵn alias k + completion
source <(kubectl completion bash); complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"              # k run web --image=nginx $do > pod.yaml
export now="--force --grace-period=0"             # k delete pod web $now
# ~/.vimrc
set expandtab tabstop=2 shiftwidth=2 autoindent number
```

- **Mỗi task: chạy lệnh `ssh <host>` / `k config use-context` trong infobox trước tiên.**
- **Nhìn prompt** (`ubuntu@cp1`, `base`) trước khi gõ lệnh: đang đứng ở host nào? (Ngày 2)
- Xong task: verify, rồi `exit` về host `base`. Không SSH lồng nhau.

### SSH (Ngày 2)

```bash
ssh <host>                         # host đã khai báo trong ~/.ssh/config
sudo -i                            # lên root trên host (đề cho phép)
ssh-keygen -R <host>               # xoá host key cũ khi máy được tạo lại
scp <host>:/path/file /tmp/        # chép về máy đang đứng
ssh -v <host>                      # debug "Permission denied": xem key nào được thử
```

## 1. Troubleshooting (30%)

### Thứ tự nhìn (Ngày 1)

```bash
k get nodes -o wide
k get pods -A -o wide | grep -v Running
k get events -A --sort-by=.lastTimestamp | tail -20
k describe <kind> <name>                       # đọc Events cuối output
k logs <pod> [-c <container>] [-p]             # -p = lần chạy trước (pod đã crash)
```

### Node NotReady (Ngày 1)

```bash
ssh <node>
sudo systemctl status kubelet containerd
sudo journalctl -u kubelet -n 50 --no-pager
# config kubelet: /var/lib/kubelet/config.yaml · kubeconfig kubelet: /etc/kubernetes/kubelet.conf
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

### systemd: service hỏng (Ngày 3)

```bash
systemctl status <svc> --no-pager          # Active? exit code? (status=203/EXEC = sai đường dẫn binary)
systemctl cat <svc>                        # file gốc + MỌI drop-in — đừng chỉ đọc file .service
journalctl -u <svc> -n 30 --no-pager       # nguyên nhân
sudo systemctl daemon-reload               # BẮT BUỘC sau khi sửa file unit/drop-in bằng tay
sudo systemctl restart <svc>
systemctl is-active <svc>; systemctl is-enabled <svc>
systemctl list-units --failed
```

Drop-in (cách kubelet nhận cờ qua `10-kubeadm.conf`):

```ini
# /etc/systemd/system/<svc>.service.d/override.conf
[Service]
ExecStart=
ExecStart=/new/command --flag
```

`ExecStart=` trống để xoá lệnh cũ, thiếu nó systemd báo lỗi 2 ExecStart. `sudo SYSTEMD_EDITOR=vim systemctl edit <svc>` → gõ **giữa** hai dòng `###`, nếu không sẽ không lưu.

### journalctl (Ngày 3)

```bash
journalctl -u kubelet -f                   # theo dõi trực tiếp
journalctl -u kubelet --since "10 min ago" --no-pager
journalctl -p err -b --no-pager | tail     # chỉ lỗi, từ lần boot này
```

### Control plane chết, kubectl không dùng được (Ngày 3)

```bash
ssh <controlplane> && sudo -i
crictl ps -a | grep -E 'apiserver|etcd|scheduler|controller'   # container Exited?
crictl logs <id> 2>&1 | tail
ls /var/log/pods/ | grep apiserver                              # log cũng ở đây
journalctl -u kubelet -n 30 --no-pager                          # YAML sai cú pháp → không có container, xem ở đây
grep staticPodPath /var/lib/kubelet/config.yaml                 # thường /etc/kubernetes/manifests
```

- Sửa manifest static pod → kubelet tự tạo lại pod (không cần apply), đợi 30–60s.
- **Backup để NGOÀI** `/etc/kubernetes/manifests` — file `.bak` trong đó cũng bị chạy.
- Thiếu scheduler → pod mới `Pending`, pod cũ vẫn chạy.

### Mạng trên node (Ngày 3)

```bash
ss -tlnp                                   # port đang lắng nghe + process
ip -br a; ip route; ip route get <ip>
nc -zv <ip> <port>                         # port mở? (refused = host sống, không có service)
curl -sk https://<ip>:6443/healthz
cat /etc/resolv.conf
```

| Component | Port |
| --- | --- |
| kube-apiserver | 6443 |
| etcd | 2379 (client), 2380 (peer) |
| kubelet | 10250 |
| kube-controller-manager | 10257 |
| kube-scheduler | 10259 |
| NodePort | 30000–32767 |

### Vim (Ngày 3)

| Thao tác | Phím |
| --- | --- |
| Thụt khối dòng | `V` chọn → `>` / `<` |
| Chèn đầu nhiều dòng | `Ctrl+v` chọn cột → `I` → gõ → `Esc` |
| Copy / xoá / dán dòng | `yy` / `dd` / `p` |
| Thay một từ | `ciw` |
| Tìm / thay | `/text` · `:%s/old/new/g` |
| Dán không lệch | `:set paste` |
| Nhảy dòng N / đầu / cuối | `NG` / `gg` / `G` |

### Lấy dữ liệu: jsonpath / custom-columns / sort-by (Ngày 5)

Mọi object là cây JSON (`k get <x> -o json`). `.a.b` đi vào trong · `[0]` phần tử đầu · `[*]` mọi phần tử.

```bash
k get pod web -o jsonpath='{.spec.containers[0].image}{"\n"}'
k get pod -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'
k get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
k get pod -A -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.metadata.creationTimestamp
k get pod -A --sort-by='.status.containerStatuses[0].restartCount'
```

- `.items[*]` chỉ trong jsonpath khi get nhiều object; custom-columns và `--sort-by` **không** dùng `.items`.
- Luôn nháy đơn; thêm `{"\n"}` để xuống dòng.
- Quá 2 phút → `-o wide`, gõ tay vào file.

### Tạo object nhanh + label (Ngày 5)

```bash
k run web --image=nginx --port=80 --labels=app=web,tier=fe $do > web.yaml
k run busy --image=busybox:1.36 --restart=Never --command -- sh -c 'sleep 3600'   # --command -- = command; -- = args
k create deploy api --image=nginx --replicas=3; k expose deploy api --port=80
k create cm cfg --from-literal=K=V; k create secret generic s --from-literal=p=x
k create job j --image=busybox:1.36 -- echo hi; k create cronjob c --image=busybox:1.36 --schedule="*/5 * * * *" -- date
k label pod web env=prod [--overwrite] · k label pod web env-     # xoá
k get pod -l 'env in (dev,stg)' · -l '!env' · -l a=b,c=d · -L app,env
k explain pod.spec --recursive | grep -i <field>
k config get-contexts · current-context · use-context X · set-context X --namespace=Y
```

## 2. Cluster Architecture (25%)

### Thành phần và luồng xử lý (Ngày 4)

| Thành phần | Dạng | Ai quản lý | Port |
| --- | --- | --- | --- |
| kube-apiserver | Static pod | kubelet | 6443 |
| etcd | Static pod | kubelet | 2379 client, 2380 peer |
| kube-scheduler | Static pod | kubelet | 10259 |
| kube-controller-manager | Static pod | kubelet | 10257 |
| kubelet | systemd | systemd | 10250 (apiserver gọi khi `logs`/`exec`), 10248 healthz localhost |
| kube-proxy | DaemonSet | DaemonSet controller | 10256 |
| coredns | Deployment | Deployment controller | 53 |

Luồng: `kubectl` → **apiserver** (lưu etcd) → deployment controller tạo RS → replicaset controller tạo Pod → scheduler ghi `nodeName` → kubelet gọi CRI (sandbox → pull → create → start). **Mọi thành phần chỉ nói chuyện với apiserver.**

```bash
k get pod -n kube-system -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind,NODE:.spec.nodeName
k get events --sort-by=.metadata.creationTimestamp      # ai làm gì, theo thứ tự
k get lease -n kube-node-lease                           # heartbeat của node
curl -sk https://localhost:6443/livez; curl -sk https://localhost:10259/healthz; curl -sk https://localhost:10257/healthz
```

Node NotReady sau ~40s không có heartbeat; pod bị evict sau thêm ~300s.

### Upgrade kubeadm, một minor mỗi lần (Ngày 1)

```bash
# --- Control plane ---
sudo sed -i 's/v1\.34/v1.35/' /etc/apt/sources.list.d/kubernetes.list   # đổi repo minor
sudo apt-get update && apt-cache madison kubeadm | head -3                # xem bản 1.35.x-*
sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm='1.35.<x>-*' && sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.35.<x>
k drain <cp> --ignore-daemonsets
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet='1.35.<x>-*' kubectl='1.35.<x>-*' && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
k uncordon <cp>

# --- Worker (drain từ control plane, phần còn lại trên worker) ---
k drain <worker> --ignore-daemonsets
ssh <worker>   # đổi repo + cài kubeadm như trên, rồi:
sudo kubeadm upgrade node
#   cài kubelet + kubectl, daemon-reload, restart kubelet, exit
k uncordon <worker>
```

### Cordon / drain (Ngày 1)

| Lệnh | Tác dụng |
| --- | --- |
| `k cordon <node>` | Đánh dấu unschedulable, pod đang chạy giữ nguyên |
| `k drain <node> --ignore-daemonsets` | Cordon + evict pod (bỏ qua pod DaemonSet) |
| `--delete-emptydir-data` | Cho phép xoá pod có emptyDir |
| `--force` | Cho phép xoá pod không có controller |
| `k uncordon <node>` | Cho phép schedule lại |

## 3. Services & Networking (20%)

### Service không thông (Ngày 1, 5)

Service tìm pod bằng **selector** → pod khớp + Ready → IP vào EndpointSlice. EndpointSlice rỗng = selector không khớp label.


```bash
k get svc <svc> -o wide
k get endpointslice -l kubernetes.io/service-name=<svc>      # rỗng → selector sai
k get pod --show-labels
k get pod <pod> -o jsonpath='{.spec.containers[*].ports[*].containerPort}'
k patch svc <svc> -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
k run tmp --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- -T 2 http://<svc>.<ns>:80
```

### Ingress nhanh (Ngày 1)

```bash
k create ingress web --class=<ingressclass> \
  --rule="app.example.com/api*=api-svc:80" \
  --rule="app.example.com/*=web-svc:80" $do > ing.yaml      # dấu * = pathType Prefix
k get ingressclass
```

## 4. Workloads & Scheduling (15%)

### Taint / toleration (Ngày 1)

```bash
k taint nodes <node> env=prod:NoSchedule        # thêm
k taint nodes <node> env=prod:NoSchedule-       # xoá (dấu - ở cuối)
k describe node <node> | grep -i taint
```

```yaml
tolerations:
  - key: env
    operator: Equal
    value: prod
    effect: NoSchedule
```

### Node affinity (Ngày 1)

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:     # bắt buộc
      nodeSelectorTerms:
        - matchExpressions:
            - { key: disktype, operator: In, values: [ssd] }
    preferredDuringSchedulingIgnoredDuringExecution:    # ưu tiên
      - weight: 50
        preference:
          matchExpressions:
            - { key: zone, operator: In, values: [a] }
```

`k label node <node> disktype=ssd` · docs: tìm "Assign Pods to Nodes using Node Affinity".

## 5. Storage (10%)

### PVC Pending — checklist (Ngày 1)

1. `k describe pvc <pvc>` → Events.
2. `k get pv,pvc,sc` → so **storageClassName**, **accessModes**, **capacity**.
3. SC `WaitForFirstConsumer` → Pending tới khi có pod: bình thường.
4. PV `Released` → `k patch pv <pv> --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'`.

### PV + PVC + pod

Mẫu: `manifests/storage/hostpath-pv-pvc-pod.yaml`. Docs: tìm "Configure a Pod to Use a PersistentVolume for Storage".
hostPath chỉ ở một node → kiểm tra persistence phải cùng node.

| Access mode | Viết tắt | Ý nghĩa |
| --- | --- | --- |
| ReadWriteOnce | RWO | Ghi được từ một **node** |
| ReadOnlyMany | ROX | Đọc từ nhiều node |
| ReadWriteMany | RWX | Ghi từ nhiều node |
| ReadWriteOncePod | RWOP | Ghi từ đúng một **pod** |

| Reclaim policy | Khi xoá PVC |
| --- | --- |
| Retain | PV thành `Released`, dữ liệu giữ nguyên, phải dọn tay |
| Delete | Xoá PV và volume phía sau (mặc định của SC động) |
