# Ngày 2 — Dựng lab (10/10/2026)

**Thời gian:** dự kiến 4h · thực tế 2h  
**Tự đánh giá:** 5/5  
**Kết quả:** đạt mục tiêu ngày — 3 node Ubuntu 24.04 trên AWS SSH được, shell đã cấu hình, repo `cka-notes` đã lên GitHub.

## Đã làm

| Việc | Kết quả | Ghi chú |
| --- | --- | --- |
| Tạo repo `cka-notes` (đúng acc `ducnghiaaa` trên máy có 2 acc) | Xong | Repo **public** (dự định private) |
| Merge Dependabot PR | PR #1 merged | #2, #3 thay bằng commit pin SHA |
| Terraform: VPC, SG, 3 EC2 | Xong | Tạo lại 3 máy một lần để đổi key SSH |
| SSH config qua `Include` + `lab.sh` | Xong | IP public đổi mỗi lần start |
| `.bashrc` / `.vimrc` trên 3 node | Xong | |
| Làm lại 2 lab Storage trên Killercoda: Persistent Volumes, Troubleshoot a Stuck PVC | Xong | Hai bài fail ở Ngày 1 |
| Stop lab | Xong | `./lab/scripts/lab.sh stop` |

IP private hiện tại: `cp1` = 10.42.1.70 · `w1` = 10.42.1.214 · `w2` = 10.42.1.159 (điền từ `terraform output private_ips`)

## Lỗi hôm nay

| # | Lỗi | Nguyên nhân | Cách đúng |
| --- | --- | --- | --- |
| 1 | CI trên `main` fail: `unable to find version 0.28.0` | Tag `trivy-action` cũ bị gỡ sau vụ tấn công chuỗi cung ứng tháng 3/2026 | Merge bản mới, **pin action theo commit SHA** thay vì tag |
| 2 | Không hiểu 3 dòng `export TF_VAR_...` | Chưa biết cách Terraform đọc biến | `TF_VAR_x` → `var.x`. Thứ tự ưu tiên: `-var` > `*.auto.tfvars` > `terraform.tfvars` > `TF_VAR_` |
| 3 | Dùng key SSH GitHub cho lab | Có sẵn key nên dùng luôn | Key riêng `~/.ssh/cka`: lộ một key không kéo theo cái kia; không bao giờ `ssh -A` vào node |
| 4 | `Include` nằm trong khối `Host github-...` | Không biết `Include` có phạm vi | `Include` đứng **đầu** `~/.ssh/config`, trước mọi khối `Host` |
| 5 | `IdentityFile ~/.ssh/cka` viết cứng, không khớp key thật | Lỗi trong output Terraform | Lấy từ biến: `trimsuffix(var.ssh_pubkey, ".pub")` |
| 6 | `zsh: no such file or directory: ~/.ssh/config.d/cka-lab` | Thư mục chưa tồn tại; `>` không tự tạo thư mục | `mkdir -p ~/.ssh/config.d` |
| 7 | `Permission denied (publickey)` sau khi đổi key | Đổi key pair không tạo lại instance; key chỉ được cài lúc máy khởi tạo. Dấu hiệu: IP public **không đổi** | `terraform apply -replace=...` cho key pair + 3 instance |
| 8 | `plan` báo `No changes` dù đã đổi `ssh_pubkey` | Chưa rõ nguyên nhân (biến đúng, không có tfvars) | Không đoán, dùng `-replace` để ép |
| 9 | `scp` chạy trên `cp1` → `Permission denied` | Nhầm đang đứng ở máy nào (prompt `ubuntu@cp1`) | Lệnh dùng alias `cp1/w1/w2` chạy từ **máy Mac**. Luôn nhìn prompt trước khi gõ |
| 10 | File `tf.plan` lọt khỏi `.gitignore` | Tên file không khớp pattern `*.tfplan` | Đặt tên `lab.tfplan`; đã thêm `tf.plan` vào `.gitignore` |

## Học được

- **Đọc dấu hiệu trước khi sửa:** IP không đổi nghĩa là máy không được tạo lại. Lỗi #7 tìm ra nhờ chi tiết này, đúng tinh thần troubleshooting CKA.
- **Prompt cho biết đang ở host nào** (lỗi #9). Đề CKA bắt `ssh <host>` ở đầu mỗi task; làm nhầm host là mất trọn điểm task đó.
- **`known_hosts`:** `ssh-keygen -R <tên>` xoá host key cũ khi máy được tạo lại. `HostKeyAlias` giúp IP đổi mà không bị hỏi lại.
- **Stop/start:** IP public đổi, IP private và ổ đĩa giữ nguyên. Elastic IP vẫn bị tính phí khi máy stop, nên không dùng.

## Ngày mai (Ngày 3 — CN 11/10)

Linux cho CKA: `systemctl`, `journalctl -u kubelet`, `ss -tlnp`, `ip route`, `crictl`, vim. Gate G1: lab sẵn sàng (đã đạt).
