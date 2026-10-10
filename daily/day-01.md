# Ngày 1 — Đánh giá đầu vào (09/10/2026)

**Thời gian:** dự kiến 2h · thực tế 2h40  
**Tự đánh giá:** 3/5  
**Kết quả:** 7/10 scenario CKA trên Killercoda (70%, trên ngưỡng đậu 66% nhưng chậm)

## Đã làm

| # | Scenario | Kết quả | Domain | Ghi chú |
| --- | --- | --- | --- | --- |
| 1 | Troubleshoot a NotReady Node | Pass | Troubleshooting | Không check trạng thái node trước nên phát hiện vấn đề muộn |
| 2 | Troubleshoot a Stuck PVC | **Fail** | Storage | Chưa có kiến thức PV/PVC |
| 3 | Troubleshoot a Broken Network Path | **Fail** | Services & Networking | Tìm ra lệch port nhưng không biết sửa Service cho đúng |
| 4 | Quick SSH: Check and Restart | Pass | Troubleshooting | |
| 5 | Upgrading Kubernetes | Pass | Cluster Architecture | Chỉ biết `kubeadm upgrade plan` / `apply` |
| 6 | Cordon and Drain the Node | Pass | Cluster Architecture | Sửa được nhưng chưa hiểu lỗi DaemonSet |
| 7 | Taints and Tolerations | Pass | Workloads & Scheduling | |
| 8 | Node Affinity: Required and Preferred | Pass | Workloads & Scheduling | |
| 9 | Create Ingress Resource | Pass | Services & Networking | |
| 10 | Persistent Volumes | **Fail** | Storage | Tạo PV, PVC, gắn pod, xoá pod rồi kiểm tra data: làm lâu, search nhiều |

## Nhận định

- **Storage là lỗ hổng lớn nhất** (2/2 fail). Theo lịch, Storage học ở tuần 9 (07/12), quá xa. Thêm 20 phút drill PV/PVC vào buổi speed drill Chủ nhật 18/10 (Ngày 10).
- **Debug Service**: biết tìm nguyên nhân nhưng chưa biết sửa. Học kỹ ở tuần 7; trước đó luyện công thức 4 bước ở cheatsheet.
- **Thói quen troubleshooting**: luôn bắt đầu bằng cái nhìn tổng thể (`k get nodes`, `k get pods -A`), rồi mới đi sâu.

## Học được

### 1. NotReady node: đi từ trên xuống

```bash
k get nodes -o wide                       # node nào NotReady?
k describe node <node> | grep -A8 Conditions
ssh <node>
sudo systemctl status kubelet containerd
sudo journalctl -u kubelet -n 50 --no-pager
# sửa (thường là kubelet dừng / config sai) rồi:
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

### 2. PVC kẹt Pending — PVC chỉ bind với PV khi khớp đủ

| Điều kiện | Kiểm tra |
| --- | --- |
| `storageClassName` giống nhau (kể cả cùng rỗng `""`) | `k get pv,pvc` cột STORAGECLASS |
| `accessModes` của PV chứa mode PVC yêu cầu | cột ACCESS MODES |
| Dung lượng PV ≥ dung lượng PVC | cột CAPACITY |
| PV đang `Available` (không phải `Released`) | cột STATUS |
| Không có PV phù hợp → cần StorageClass để tạo động | `k get sc` |

- `k describe pvc <pvc>` → đọc **Events** trước tiên.
- SC dùng `volumeBindingMode: WaitForFirstConsumer` → PVC `Pending` tới khi có pod dùng nó: **bình thường**, không phải lỗi.
- PV `Released` (PVC cũ đã xoá, reclaim `Retain`) → muốn dùng lại thì xoá `claimRef`:
  `k patch pv <pv> --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'`

### 3. Broken network path — công thức 4 bước

```bash
k get svc <svc> -o wide                                        # selector, port, targetPort
k get endpointslice -l kubernetes.io/service-name=<svc>        # rỗng → selector không khớp label pod
k get pod -l <selector> -o jsonpath='{.items[*].spec.containers[*].ports[*].containerPort}'
# targetPort phải = containerPort. Sửa:
k patch svc <svc> -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}'
# hoặc k edit svc <svc>
# Verify từ trong cluster:
k run tmp --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- -T 2 http://<svc>.<ns>:80
```

Ngoài ra kiểm tra NetworkPolicy chặn (`k get netpol -A`) nếu endpoint đúng mà vẫn không vào được.

### 4. Upgrade: không chỉ có plan/apply

Thứ tự: control plane trước, worker sau, mỗi lần một node, chỉ lên **một minor**. Lệnh chi tiết ở `cheatsheet.md` → Cluster Architecture → Upgrade.

### 5. Vì sao drain báo lỗi DaemonSet

DaemonSet controller tạo lại pod của nó trên mọi node, kể cả node đã cordon (DaemonSet tự có toleration `node.kubernetes.io/unschedulable`). Nếu drain xoá pod đó, pod sẽ quay lại ngay, nên `kubectl drain` từ chối. `--ignore-daemonsets` bảo drain bỏ qua chúng.

| Lỗi khi drain | Cờ cần thêm |
| --- | --- |
| `cannot delete DaemonSet-managed Pods` | `--ignore-daemonsets` |
| `cannot delete Pods with local storage` (emptyDir) | `--delete-emptydir-data` (mất dữ liệu emptyDir) |
| `cannot delete Pods not managed by a controller` | `--force` (pod mất hẳn, không được tạo lại) |
| Bị PodDisruptionBudget chặn, lặp lại mãi | Kiểm tra `k get pdb -A`; không xoá PDB trừ khi đề yêu cầu |

### 6. PV + PVC + pod (hostPath)

Mẫu: `manifests/storage/hostpath-pv-pvc-pod.yaml`. Lưu ý: **hostPath nằm trên đĩa của một node**. Xoá pod rồi tạo pod mới ở node khác sẽ thấy thư mục rỗng; muốn kiểm chứng dữ liệu còn, pod mới phải chạy cùng node (PV có `nodeAffinity`, hoặc pod có `nodeName`).

## Ngày mai (Ngày 2 — 10/10)

Dựng lab bằng Terraform (`lab/terraform`), `trivy config` sạch, SSH được cả 3 node, cấu hình `.bashrc` / `.vimrc`.
