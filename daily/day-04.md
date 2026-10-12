1. 
Cluster Architecture
Control plane gồm những thành phần nào? Thành phần nào chạy trên mọi node?
Control plane bao gồm: kube-apiserver, etcd, kube-scheduler, kube-controller-manager
Thành phần chạy trên mọi node: kubelet, kube-proxy (optional) and container runtime

Kubernetes Components
Mỗi thành phần làm đúng một việc gì?
kube-apiserver: Thành phần như một cánh cửa của Kubernetes API, hình dung API server như một front end của Kubernetes control plane.
etcd: Lưu trữ dạng key-value đảm bảo tính nhất quán và sẵn sàng cao, sử dụng được lưu trữ tất cả dữ liệu của cụm.
kube-scheduler: Thành phần theo dõi các Pod được tạo, chọn Node để Pod chạy.
kube-controller-manager: Thành phần chạy các tiến trình controller. Bao gồm nhiều loại controllers như: Node controller, Job controller, ...
cloud-controller-manager: Nó cho phép cụm của bạn kết nối đến API Kubbernetes của các Cloud Providers.
kubelet: agent chạy ở mỗi node trong cluster. Nó đảm bảo containers chạy trong Pod
kube-proxy (optional): proxy chạy ở mỗi node, triển khai 1 dịch vụ phổ biến đó là Service
container runtime: Thành phần cơ bản giúp Kubernetes vận hành container 1 cách hiệu quả. Nó đảm nhận việc quản lý thực thi và vòng đời của container

Ports and Protocols
Mỗi thành phần lắng nghe port nào? Ai gọi tới port đó?
kube-apiserver: 6443, được sử dụng bởi tất cả
etcd: 2379-2380, được sử dụng bởi kube-apiserver,etcd
kubelet: 10250, được sử dụng self, control plane
kube-scheduler: 10259, được sử dụng self
kube-controller-manager, được sử dụng self
kube-proxy: 10256, self và load balencers
NodePort Services: TCP/UDP, 30000-32767, sử dụng ALL

Nodes (mục Heartbeats)
Node bị coi là NotReady sau bao lâu? Dựa vào đâu?
5 phút sẽ cập nhật status, đối với các node khong truy cập được là 40s
Kubelet tạo và cập nhật trạng thái Lease mỗi 10s (mặc định). Nếu Lease cập nhật fail, kubelet sẽ retry

2. 
- kube-apiserver, etcd, scheduler, controller-manager ; Node ; Control Plane
- cilium-envoy-7nwgk                     DaemonSet    controlplane
    cilium-envoy-bp5gr                     DaemonSet    node01
    cilium-h4qjm                           DaemonSet    controlplane
    cilium-kbr55                           DaemonSet    node01
    cilium-operator-86477b5bf8-cn7dc       ReplicaSet   controlplane
- Chưa biết ai quản lý?

3. 
a. Gửi tới port 6443 (là port của apiserver)
b. Biết được scheduled do default-scheduler đã pulling, pulled. Scheduler chỉ ghi spec.nodeName vào pod, không tự chạy container. Kubelet đã created, Started container
c. Chưa hiểu pod sandbox ở đâu ra? Mà container xin ra pid là 1 thì như nào
d. Chưa hiểu chuỗi, là controller có nhiều loại, ở đây deploy controller và repl controller đã đẩy Pod sang scheduler -> Node -> kubelet -> container à

4. 
Biết được mọi object trong etcd dưới dạng key. Chỉ apiserver được đọc và ghi etcd. Xem file manifest etcd để xem path của cert thay vì nhớ

5. 
Chỉ thấy apiserver và kubelet listen ở mọi địa chỉ, còn lại chỉ lắng nghe localhost

6. 
Nếu dừng controller-manager thì k get pod còn chạy, k create deploy sẽ không còn tạo được pod nữa vì không có tiến trình controller
Nếu dừng scheduler thì việc Pod mới được run sẽ bị Pending vì không có ai điều phối nó cả, không ai gắn vào .specnodeName.
Nếu dừng kebelet trên node01 thì Node01 sẽ bị Notready, node01 sẽ ko giao tiếp được với control plane và các Pod trên Node01 sẽ Pending chứ chưa chết ngay

7. 
Luồng từ khi ấn k create deploy. Lúc đó apiserver sẽ ghi lại như 1 object vào etcd, sau đó default-schedule sẽ thực hiện pulling, và đánh spec.nodeName cho Pod. Và kubelet sẽ thực hiện create/run container trên Pod
Trả lời câu hỏi:
apiserver là thành pầnn duy nhất đọc và ghi vào etcd
Scheduler ghi spec.nodeName vào Pod
Tôi không biết nhưng tôi đoán là controller
Static pod tôi không biết ai quản lý
Kubelet nói chuyện với containerd qua cri, container runtime interface
proxy chạy dưới dạng replicaset và nó như là 1 bộ cân bằng tải cho Service
port của apiserver: 6443, etcd (client 2379, peer 2380), kubelet: 10250, scheduler: 10259, controller-manager: không nhớ
khi kubelet dừng, container đang chạy trên node đó ko chết