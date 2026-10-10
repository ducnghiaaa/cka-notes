terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "cka-lab", Owner = var.owner, ManagedBy = "terraform" }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "owner" {
  type = string
}

variable "admin_cidr" {
  type        = string
  description = "Your public IP as x.x.x.x/32"
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a single host /32."
  }
}

variable "ssh_pubkey" {
  type        = string
  description = "Path to SSH public key, e.g. ~/.ssh/cka.pub"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "nodes" {
  description = "name => role. Week 3 (HA) add: cp2 = control-plane, cp3 = control-plane, lb = lb"
  type        = map(string)
  default     = { cp1 = "control-plane", w1 = "worker", w2 = "worker" }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.42.0.0/16" # does not overlap pod CIDR 192.168.0.0/16
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_subnet" "lab" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.42.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

# Descriptions must be ASCII: AWS rejects non-ASCII characters in SG rule descriptions.
resource "aws_security_group" "nodes" {
  name        = "cka-nodes"
  description = "CKA lab nodes"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH from admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "NodePort tests from admin IP only"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "All intra-cluster traffic (API, etcd, kubelet, CNI)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
  egress {
    description = "Image pulls and apt repos (accepted for lab)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "lab" {
  key_name   = "cka-lab"
  public_key = file(pathexpand(var.ssh_pubkey))
}

resource "aws_instance" "node" {
  for_each               = var.nodes
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = each.value == "lb" ? "t3.small" : var.instance_type
  subnet_id              = aws_subnet.lab.id
  vpc_security_group_ids = [aws_security_group.nodes.id]
  key_name               = aws_key_pair.lab.key_name
  source_dest_check      = false # needed for pod routing without encapsulation

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }
  user_data = <<-EOT
    #!/bin/bash
    hostnamectl set-hostname ${each.key}
  EOT

  tags = { Name = each.key, Role = each.value }
}

output "ssh_config" {
  description = "Ghi vào ~/.ssh/config.d/cka-lab: terraform output -raw ssh_config > ~/.ssh/config.d/cka-lab"
  value = join("", [for k, n in aws_instance.node : <<-EOT
    Host ${k}
      HostName ${n.public_ip}
      User ubuntu
      IdentityFile ~/.ssh/cka
      IdentitiesOnly yes
      HostKeyAlias cka-${k}
      StrictHostKeyChecking accept-new

    EOT
  ])
}

output "private_ips" {
  value = { for k, n in aws_instance.node : k => n.private_ip }
}

