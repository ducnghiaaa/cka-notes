# Ngày 4 — Kiến trúc cluster (12/10/2026)

**Thời gian:** dự kiến 2h · thực tế 1h30  
**Tự đánh giá:** _/5  
**Kết quả:** làm đủ 7 phần trên Killercoda. Tự kiểm tra **5/8** câu (đúng 1, 2, 5, 8; đúng một nửa 3, 7; sai 4, 6).

## Thành phần chạy dưới dạng gì

| Thành phần | Dạng | Ai quản lý | Ở đâu |
| --- | --- | --- | --- |
| kube-apiserver, etcd, kube-scheduler, kube-controller-manager | Static pod (OWNER = `Node`) | **kubelet** đọc `/etc/kubernetes/manifests` | Control plane |
| kube-proxy, CNI (cilium, calico…) | DaemonSet | DaemonSet controller | Mọi node |
| coredns, cilium-operator | Deployment → ReplicaSet | Deployment + ReplicaSet controller | Bất kỳ |
| kubelet, containerd | Service systemd | systemd | Mọi node |

- `k get pod` chỉ thấy **mirror pod** của static pod → `k delete` xong pod quay lại ngay. Muốn dừng thật: chuyển file manifest ra khỏi thư mục.
- Cluster Killercoda dùng Cilium thay kube-proxy, nên không có pod kube-proxy. Lab kubeadm tuần 2 sẽ có.

## Luồng `k create deploy` → container chạy

Mọi thành phần **chỉ nói chuyện với apiserver**; mỗi thành phần canh (watch) loại object mình phụ trách, làm việc, rồi ghi kết quả lại.

```
k create deploy web
   │  (1) POST Deployment
   ▼
┌──────────────┐  ghi/đọc  ┌──────┐
│ kube-apiserver│◄────────►│ etcd │
└──────────────┘           └──────┘
   ▲  ▲  ▲  ▲
   │  │  │  └─(5) kubelet node01: canh "pod có nodeName = node01"
   │  │  │        → CRI: sandbox → pull → create → start → báo status
   │  │  └────(4) scheduler: canh "pod chưa có nodeName"
   │  │            → chọn node → ghi Binding (nodeName)
   │  └───────(3) replicaset controller: canh ReplicaSet → tạo N Pod
   └──────────(2) deployment controller: canh Deployment → tạo ReplicaSet
   (2) và (3) chạy trong kube-controller-manager
```

Kiểm chứng: `k get events --sort-by=.metadata.creationTimestamp` (SOURCE: `default-scheduler` → `kubelet`), `ownerReferences` Pod → ReplicaSet → Deployment.

## Thành phần chết → triệu chứng

| Dừng | Triệu chứng | Bước bị đứt |
| --- | --- | --- |
| kube-apiserver | `kubectl` báo `connection refused` 6443; workload đang chạy vẫn chạy | Tất cả |
| etcd | apiserver lỗi/khởi động lại liên tục | Lưu trữ |
| controller-manager | Deployment được lưu nhưng không có RS/Pod; `k get` vẫn chạy | (2)(3) |
| scheduler | Pod mới `Pending`, `nodeName` trống; pod cũ vẫn chạy | (4) |
| kubelet trên 1 node | Node NotReady sau ~40s; pod vẫn hiện `Running` (trạng thái cũ), container vẫn chạy; ~5 phút sau pod bị evict, controller tạo lại ở node khác | (5) |

## Heartbeat của node

| Mốc | Sự kiện |
| --- | --- |
| Mỗi 10s | kubelet gia hạn Lease trong `kube-node-lease` |
| ~40s không có Lease | Node → NotReady/Unknown (`--node-monitor-grace-period` của controller-manager) |
| +300s | Pod bị evict (taint `node.kubernetes.io/unreachable`, `tolerationSeconds: 300`) |

## Pod sandbox

kubelet gọi CRI `RunPodSandbox` trước: tạo container `pause` giữ **network namespace** (IP của pod). Container ứng dụng gia nhập namespace đó → các container cùng pod chung IP, gọi nhau qua `localhost`.

```bash
PID=$(crictl inspect -o go-template --template '{{.info.pid}}' <container-id>)
ps -p $PID -o pid,cmd     # PID thật trên node; trong container tiến trình này là PID 1
```

## Lỗi / hiểu sai hôm nay

| # | Hiểu sai | Đúng |
| --- | --- | --- |
| 1 | Scheduler pull image | kubelet pull image; scheduler chỉ chọn node |
| 2 | Controller "đẩy" Pod sang scheduler | Không ai gọi trực tiếp ai; tất cả watch apiserver |
| 3 | Không biết ai quản lý static pod | kubelet |
| 4 | kube-proxy chạy dạng ReplicaSet, là load balancer | DaemonSet; ghi luật iptables/IPVS/nftables cho Service |
| 5 | Quên port controller-manager | 10257 |
| 6 | Kubelet dừng → pod Pending | Pod vẫn hiện Running (trạng thái cũ) tới khi bị evict |
| 7 | `crictl inspect` ra PID = 1 | Do lệnh `grep` của hướng dẫn bắt nhầm `namespaceOptions`; dùng go-template `{{.info.pid}}` |
| 8 | Chỉ apiserver, kubelet lắng nghe mọi địa chỉ | etcd lắng nghe `127.0.0.1` **và** IP node (`--listen-client-urls`) |

## Ôn lại (13/10, trước khi học)

Không xem note: trả lời lại câu 3, 4, 6, 7 và vẽ lại sơ đồ 5 bước.

## Ngày mai (Ngày 5 — T3 13/10)

Pod & imperative: `k run ... $do`, labels/selectors, `k explain --recursive`, `-o jsonpath`, `custom-columns`, `--sort-by`.
