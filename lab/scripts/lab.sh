#!/usr/bin/env bash
# Bật/tắt lab CKA, ghi SSH config theo public IP mới. KHÔNG ghi Terraform state.
# Dùng: ./lab.sh start | stop | status
set -euo pipefail

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
SSH_CFG="${HOME}/.ssh/config.d/cka-lab"
FILTER="Name=tag:Project,Values=cka-lab"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

[[ -f "${TF_DIR}/.env" ]] && source "${TF_DIR}/.env"
: "${AWS_PROFILE:?thiếu AWS_PROFILE trong lab/terraform/.env}"
: "${EXPECTED_AWS_ACCOUNT:?thiếu EXPECTED_AWS_ACCOUNT trong lab/terraform/.env}"
: "${TF_VAR_ssh_pubkey:?thiếu TF_VAR_ssh_pubkey}"
export AWS_PROFILE AWS_REGION="${AWS_REGION:-ap-southeast-1}"

# Chặn chạy nhầm tài khoản AWS
acct="$(aws sts get-caller-identity --query Account --output text)" || die "không xác thực được AWS (profile ${AWS_PROFILE})"
[[ "$acct" == "$EXPECTED_AWS_ACCOUNT" ]] || die "đang ở account ${acct}, lab nằm ở ${EXPECTED_AWS_ACCOUNT}"

ids() {
  aws ec2 describe-instances --filters "$FILTER" "Name=instance-state-name,Values=$1" \
    --query 'Reservations[].Instances[].InstanceId' --output text
}

write_ssh() {
  local key="${TF_VAR_ssh_pubkey%.pub}"
  mkdir -p "$(dirname "$SSH_CFG")"
  aws ec2 describe-instances --filters "$FILTER" Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PublicIpAddress]' --output text |
  sort | while read -r name ip; do
    printf 'Host %s\n  HostName %s\n  User ubuntu\n  IdentityFile %s\n  IdentitiesOnly yes\n  HostKeyAlias cka-%s\n  StrictHostKeyChecking accept-new\n\n' \
      "$name" "$ip" "$key" "$name"
  done > "${SSH_CFG}.tmp"
  [[ -s "${SSH_CFG}.tmp" ]] || { rm -f "${SSH_CFG}.tmp"; die "không có instance running nào, giữ nguyên SSH config cũ"; }
  mv "${SSH_CFG}.tmp" "$SSH_CFG" && chmod 600 "$SSH_CFG"
  log "SSH config: $SSH_CFG"
}

check_sg() {
  local my_ip; my_ip="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')/32"
  local allowed; allowed="$(aws ec2 describe-security-groups --filters "$FILTER" Name=group-name,Values=cka-nodes \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].IpRanges[].CidrIp' --output text)"
  if [[ " $allowed " != *" $my_ip "* ]]; then
    log "IP của bạn (${my_ip}) chưa được mở SSH (đang mở: ${allowed:-không có})."
    log "Cập nhật: cd ${TF_DIR} && export TF_VAR_admin_cidr=${my_ip} && terraform plan -out lab.tfplan  (kiểm tra CHỈ đổi SG) && terraform apply lab.tfplan"
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
    write_ssh
    check_sg
    sleep 20
    for h in cp1 w1 w2; do
      ssh -o ConnectTimeout=5 "$h" true 2>/dev/null && log "$h: SSH OK" || log "$h: chưa SSH được"
    done
    ;;
  stop)
    to_stop="$(ids running)"
    [[ -z "$to_stop" ]] && { log "Không có instance nào đang chạy"; exit 0; }
    log "Stop: $to_stop"
    aws ec2 stop-instances --instance-ids $to_stop >/dev/null
    aws ec2 wait instance-stopped --instance-ids $to_stop
    log "Đã stop."
    ;;
  status)
    aws ec2 describe-instances --filters "$FILTER" \
      --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,State.Name,PublicIpAddress,PrivateIpAddress]' \
      --output table
    ;;
  *) echo "Dùng: $0 start|stop|status"; exit 1 ;;
esac
