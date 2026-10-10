# Lab Terraform

```bash
ssh-keygen -t ed25519 -f ~/.ssh/cka -C cka-lab -N ""      # một lần
export TF_VAR_owner="<your-name>"
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
export TF_VAR_ssh_pubkey="~/.ssh/cka.pub"

terraform init
terraform fmt -check && terraform validate
tflint
trivy config --severity HIGH,CRITICAL .
terraform apply
terraform output -raw ssh_config >> ~/.ssh/config
```

Trivy sẽ báo 2 finding đã chấp nhận cho lab: egress `0.0.0.0/0` và subnet gán public IP. Không dùng mẫu này cho production (production: private subnet + NAT + SSM Session Manager).

Public IP đổi sau mỗi lần stop/start: chạy `terraform apply -refresh-only` rồi cập nhật `~/.ssh/config`. Nhớ stop instance khi không học.
