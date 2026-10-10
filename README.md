# cka-notes

Ghi chú ôn thi CKA (Kubernetes v1.35), lộ trình 90 ngày: 09/10/2026 → thi 06/01/2027.

| Thư mục / file | Dùng để |
| --- | --- |
| `cheatsheet.md` | Lệnh và mẫu YAML phải thuộc, gom theo domain. Cập nhật sau mỗi buổi học |
| `daily/day-XX.md` | Nhật ký từng ngày: làm gì, kết quả, sai gì, học được gì |
| `daily/_template.md` | Mẫu cho ngày mới |
| `manifests/` | YAML mẫu đã chạy được, xếp theo domain |
| `lab/terraform/` | Hạ tầng lab trên AWS (3 node Ubuntu 24.04) |
| `lab/scripts/` | `lab.sh` bật/tắt lab, `node-prep.sh` chuẩn bị node cho kubeadm |

Theo dõi tiến độ (trạng thái, giờ học, điểm mock, mistake log) nằm ở file Excel `CKA_Lo_trinh_90_ngay.xlsx`, không nằm trong repo.

## Quy trình mỗi ngày

1. `cp daily/_template.md daily/day-XX.md` và ghi trong lúc học.
2. Lệnh mới phải nhớ → thêm vào `cheatsheet.md` đúng mục.
3. YAML chạy đúng → lưu vào `manifests/<domain>/`.
4. `git add -A && git commit -m "day XX: <chủ đề>" && git push`.

## Quy tắc an toàn

- Không commit: `*.tfstate`, `*.tfvars`, kubeconfig, private key, cert, file etcd snapshot (`.gitignore` đã chặn; pre-commit chạy gitleaks).
- Không chép đề thi thật hay lời giải Killer.sh vào repo. Đề CKA nằm dưới thoả thuận bảo mật của Linux Foundation; chỉ ghi lại khái niệm và lỗi của chính mình.
- Repo đang **public**: không ghi public IP của bạn, AWS Account ID, output `ssh_config` vào note. IP private `10.42.x.x` thì không sao.
- Đã bật Secret scanning + Push protection trong Settings → Code security.
