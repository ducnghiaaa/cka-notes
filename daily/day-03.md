# Ngày 3 — Linux cho CKA (11/10/2026)

**Thời gian:** dự kiến 1h30 · thực tế 1h30  
**Tự đánh giá:** 5/5  
**Kết quả:** đạt mục tiêu ngày. Break-fix apiserver **< 8 phút** (mục tiêu ≤ 8). Gate G1 (lab sẵn sàng) đạt.

## Đã làm

| Phần | Kết quả | Ghi chú |
| --- | --- | --- |
| systemd: dựng `demo.service`, phá (`python9` → status=203/EXEC), sửa | Xong | Cần `daemon-reload` sau khi sửa file unit |
| Drop-in override đổi port 8080 → 9090 | Xong | Lần 1 `systemctl edit` không lưu; làm lại được, cả bằng `tee` |
| journalctl: `-u`, `-f`, `--since`, `-p err` | Xong | |
| Mạng: `ss -tlnp`, `ip`, `nc` từ `w1` vào `cp1` | Xong | 6443 bị từ chối vì chưa có apiserver |
| Killercoda: kubelet, `crictl`, static pod | Xong | |
| Break-fix 1: scheduler mất → pod Pending | Xong | |
| Break-fix 2: apiserver sai `--etcd-servers` | Xong, < 8' | |
| Break-fix 3: kubelet dừng → node NotReady | Xong | |
| Vim drill | Xong | |

## Lỗi hôm nay

| # | Lỗi | Nguyên nhân | Cách đúng |
| --- | --- | --- | --- |
| 1 | `lab.sh start` báo không có instance, SSH config rỗng, plan đòi tạo lại tất cả | Terminal mới chưa có `AWS_PROFILE` → gọi nhầm account; `lab.sh` bản cũ chạy `refresh-only -auto-approve` nên **xoá 3 máy khỏi state** | Khôi phục `terraform.tfstate.backup`. `lab.sh` mới kiểm tra account, không ghi state |
| 2 | `terraform plan` hỏi `var.admin_cidr`, `var.owner`... | Terminal mới, chưa `source .env` | `source .env` trước mọi lệnh terraform; không Enter bỏ trống |
| 3 | `ssh cp1` timeout | IP nhà đổi (103.199.40.91 → 14.226.247.4), security group chỉ mở IP cũ | `export TF_VAR_admin_cidr=...` → plan (1 to change) → apply |
| 4 | Plan "9 to change" làm hoảng | Tag `Owner` trong `.env` (`ducnghia`) khác lần dựng đầu (`nghiand`) | Đọc **loại** thay đổi, không chỉ con số; `~ update in-place` vô hại, `destroy` mới phải dừng |
| 5 | `systemctl edit` không tạo drop-in | Gõ ngoài vùng giữa hai dòng `###` hoặc thoát không lưu | Gõ giữa hai dòng `###`; kiểm tra lại bằng `systemctl cat` |
| 6 | `lab/terraform/tf.plan` bị commit lên repo public ở Ngày 2 | `.gitignore` mới (chặn `tf.plan`) chưa được chép vào repo | `git rm --cached`; file chỉ chứa IP nhà cũ (đã đổi) và public key GitHub (vốn công khai) nên không cần viết lại history |

## Học được

- **Luôn `systemctl cat`, đừng chỉ đọc file `.service`.** Drop-in ghi đè lên file gốc; kubelet nhận cờ qua `10-kubeadm.conf`.
- **status=203/EXEC** = binary trong `ExecStart` không tồn tại hoặc không chạy được.
- **Control plane chết:** `crictl ps -a` → `crictl logs` → `/var/log/pods` → `journalctl -u kubelet`. Backup manifest để ngoài thư mục manifests.
- **Script tự động phải kiểm tra mình đang ở đâu** (account, host) trước khi ghi. Cùng tinh thần với `ssh`/`use-context` đầu mỗi task CKA.

## Ngày mai (Ngày 4 — T2 12/10)

Kiến trúc cluster: luồng `kubectl apply` → apiserver → etcd → scheduler → kubelet → CRI; thuộc port từng component (đã có bảng trong cheatsheet).
