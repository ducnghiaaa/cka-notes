#!/usr/bin/env bash
# Bật/tắt lab CKA và cập nhật SSH config theo public IP mới.
# Dùng: ./lab.sh start | stop | status     (chạy từ bất kỳ đâu trong repo)
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
SSH_CFG="${HOME}/.ssh/config.d/cka-lab"
FILTER="Name=tag:Project,Values=cka-lab"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

command -v aws >/dev/null || die "thiếu aws cli"
command -v terraform >/dev/null || die "thiếu terraform"
[[ -f "${TF_DIR}/.env" ]] && source "${TF_DIR}/.env"   # TF_VAR_owner, TF_VAR_ssh_pubkey (file đã gitignore)
: "${TF_VAR_owner:?đặt TF_VAR_owner (hoặc ghi vào lab/terraform/.env)}"
: "${TF_VAR_ssh_pubkey:?đặt TF_VAR_ssh_pubkey}"
export TF_VAR_admin_cidr="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32"

ids() {
  aws ec2 describe-instances --filters "$FILTER" "Name=instance-state-name,Values=$1" \
    --query 'Reservations[].Instances[].InstanceId' --output text
}

refresh_ssh() {
  cd "$TF_DIR"
  terraform apply -refresh-only -auto-approve -input=false >/dev/null
  mkdir -p "$(dirname "$SSH_CFG")"
  terraform output -raw ssh_config > "$SSH_CFG" && echo >> "$SSH_CFG"
  chmod 600 "$SSH_CFG"
  log "SSH config cập nhật: $SSH_CFG"
  # IP của bạn đổi → security group cần apply lại thì mới SSH được
  set +e; terraform plan -detailed-exitcode -input=false -lock=false >/dev/null; rc=$?; set -e
  if [[ $rc -eq 2 ]]; then
    log "Hạ tầng lệch với code (thường do IP của bạn đổi: ${TF_VAR_admin_cidr})."
    log "Chạy: cd ${TF_DIR} && terraform plan -out lab.tfplan && terraform apply lab.tfplan"
  elif [[ $rc -ne 0 ]]; then
    die "terraform plan lỗi"
  fi
}

case "${1:-}" in
  start)
    to_start="$(ids stopped)"
    if [[ -n "$to_start" ]]; then
      log "Start: $to_start"
      aws ec2 start-instances --instance-ids $to_start >/dev/null
      aws ec2 wait instance-running --instance-ids $to_start
    else
      log "Không có instance nào đang stopped"
    fi
    refresh_ssh
    for h in cp1 w1 w2; do
      ssh -o ConnectTimeout=5 "$h" true 2>/dev/null && log "$h: SSH OK" || log "$h: chưa SSH được (đợi 30s rồi thử lại)"
    done
    ;;
  stop)
    to_stop="$(ids running)"
    [[ -z "$to_stop" ]] && { log "Không có instance nào đang chạy"; exit 0; }
    log "Stop: $to_stop"
    aws ec2 stop-instances --instance-ids $to_stop >/dev/null
    aws ec2 wait instance-stopped --instance-ids $to_stop
    log "Đã stop. Vẫn tính phí ổ EBS và không tính phí giờ máy."
    ;;
  status)
    aws ec2 describe-instances --filters "$FILTER" \
      --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,State.Name,PublicIpAddress,PrivateIpAddress]' \
      --output table
    ;;
  *) echo "Dùng: $0 start|stop|status"; exit 1 ;;
esac