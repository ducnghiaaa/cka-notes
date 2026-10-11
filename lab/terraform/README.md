# Lab Terraform

3 node Ubuntu 24.04 (`cp1`, `w1`, `w2`, t3.medium) trong VPC `10.42.0.0/16`, region `ap-southeast-1`.

## Lần đầu

```bash
# 1. Key SSH riêng cho lab (không dùng chung key GitHub)
ssh-keygen -t ed25519 -f ~/.ssh/cka -C cka-lab -N ""

# 2. Biến Terraform: lưu vào lab/terraform/.env (đã gitignore), lab.sh tự đọc
cat > .env <<'EOT'
export AWS_PROFILE="cka"
export AWS_REGION="ap-southeast-1"
export EXPECTED_AWS_ACCOUNT="<12 số account của lab>"   # lab.sh dừng nếu đang ở account khác
export TF_VAR_owner="nghiand"
export TF_VAR_ssh_pubkey="~/.ssh/cka.pub"
EOT
source .env
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"

# 3. Kiểm tra và dựng
terraform init
terraform fmt -check && terraform validate
tflint
trivy config --severity HIGH,CRITICAL .
terraform plan -out lab.tfplan
terraform apply lab.tfplan

# 4. SSH config: file riêng, ~/.ssh/config chỉ cần dòng Include ở ĐẦU file
mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh/config.d
grep -q 'Include ~/.ssh/config.d/\*' ~/.ssh/config || \
  { printf 'Include ~/.ssh/config.d/*\n\n' | cat - ~/.ssh/config > /tmp/sshcfg && mv /tmp/sshcfg ~/.ssh/config; }
terraform output -raw ssh_config > ~/.ssh/config.d/cka-lab
chmod 600 ~/.ssh/config ~/.ssh/config.d/cka-lab
ssh cp1 hostname
```

## Hằng ngày

```bash
./lab/scripts/lab.sh start    # start → lấy IP mới → ghi lại ~/.ssh/config.d/cka-lab → thử SSH
./lab/scripts/lab.sh status
./lab/scripts/lab.sh stop     # LUÔN chạy cuối buổi
```

| Sau stop/start | |
| --- | --- |
| Public IP | Đổi (lab.sh tự cập nhật SSH config) |
| Private IP, ổ đĩa, cluster | Giữ nguyên |
| Chi phí khi stop | Không tính giờ máy, vẫn tính EBS ~$8–9/tháng |

`lab.sh` chỉ đọc AWS (theo tag `Project=cka-lab`), **không ghi Terraform state**.

### Khi IP nhà bạn đổi (lab.sh báo "chưa được mở SSH")

```bash
cd lab/terraform
source .env
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
terraform plan -out lab.tfplan     # đúng: 0 to add, 1 to change (aws_security_group.nodes), 0 to destroy
terraform apply lab.tfplan
```

Terminal mới → phải `source .env` trước mọi lệnh `terraform`, nếu không Terraform sẽ hỏi giá trị biến (đừng Enter bỏ trống).

### Nếu state bị mất (plan đòi tạo lại mọi thứ dù máy vẫn còn)

Thường do chạy với sai `AWS_PROFILE`. Terraform giữ bản trước lần ghi gần nhất:

```bash
export AWS_PROFILE=cka && aws sts get-caller-identity
terraform state list -state=terraform.tfstate.backup | grep aws_instance   # đủ 3 node?
cp terraform.tfstate terraform.tfstate.broken && cp terraform.tfstate.backup terraform.tfstate
terraform plan                                                              # No changes
```

Không bao giờ dùng `terraform apply -refresh-only -auto-approve` trong script.

## Đổi SSH key

Key chỉ được cài vào máy lúc khởi tạo. Đổi `ssh_pubkey` **không** làm Terraform tạo lại instance (tên key pair vẫn là `cka-lab`), nên phải ép:

```bash
terraform plan -out lab.tfplan -replace=aws_key_pair.lab \
  -replace='aws_instance.node["cp1"]' -replace='aws_instance.node["w1"]' -replace='aws_instance.node["w2"]'
terraform apply lab.tfplan
terraform output -raw ssh_config > ~/.ssh/config.d/cka-lab
ssh-keygen -R cka-cp1; ssh-keygen -R cka-w1; ssh-keygen -R cka-w2
```

Tạo lại instance = mất mọi thứ đã cài và đổi IP private.

## Ghi chú bảo mật

Trivy báo 2 finding đã chấp nhận cho lab (egress `0.0.0.0/0`, subnet gán public IP) trong `.trivyignore`. Production: private subnet + NAT + SSM Session Manager, không mở SSH ra Internet.
