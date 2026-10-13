1. Ôn
a. Ôn ngày 4: 10'
kubelet sẽ quản lý những static pod và nó sẽ được chạy trên control plane
kube-proxy chạy dưới dạng DaemonSet và nó sẽ được DaemonSet Controller quản lý, được chạy trên mọi node
Port của controller-manager là 10257
Sơ đồ 5 bước từ k create deploy web cho đến container chạy
(1) k create deploy web -> apiserver -> ghi/đọc vào etcd
(2) Deployment controller sẽ watch deployment và tạo ReplicaSet
(3) Replica controller sẽ watch replicaset từ bước trên sau đó sẽ tạo Pod
(4) Scheduler sẽ watch Pod chưa có nodeName để chọn node gán nodeName (binding)
(5) kubelet, ví dụ kubelet node1 sẽ watch những pod có nodeName là node1 qua tiếp Container Runtime Interface -> Pull -> Create -> Start -> và báo lại status
Các bước trên đều phải giao tiếp qua apiserver

b. Mistake log thực hành: Tầm ~20'
NodeReady node: done 2'
Broken Network Path: done 2'
Drain: done 2'
Stuck PVC: 4'39s
Persisdent Volumes: 6'19s

c. Mistake log khái niệm:
- Các bước upgrade: Phải upgrade kubeadm version lớn hay hoặc bằng target version trước, sau đó xác minh ằng upgrade plan và cuối cùng là kubeadm apply v.xx.xx
- Kubelet quản lý static pod
- Kube-proxy làm nhiệm vụ như một load-balance, cân bằng tải cho Pod
- k create deploy gồm 5 luồng: Sơ đồ 5 bước từ k create deploy web cho đến container chạy
(1) k create deploy web -> apiserver -> ghi/đọc vào etcd
(2) Deployment controller sẽ watch deployment và tạo ReplicaSet
(3) Replica controller sẽ watch replicaset từ bước trên sau đó sẽ tạo Pod
(4) Scheduler sẽ watch Pod chưa có nodeName để chọn node gán nodeName (binding)
(5) kubelet, ví dụ kubelet node1 sẽ watch những pod có nodeName là node1 qua tiếp Container Runtime Interface -> Pull -> Create -> Start -> và báo lại status. Các bước trên đều phải giao tiếp qua apiserver
- TÔi nghĩ đổi key thì key sẽ không còn đúng nữa nên sẽ bị báo là bị từ chối quyền hoặc không đủ quyền truy cập
- không biết tại sao phải nhìn prompt trước khi gõ lệnh
- Include trong SSH config phải đặt ở máy local

d. Flashcard
Sai câu 7, 9, 12, 22, với mấy phần workloads & scheduling chưa ổn lắm

2. Đọc Docs