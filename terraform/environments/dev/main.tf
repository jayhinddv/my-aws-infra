###############################################################################
# Environment root - calls the modules to build ONE complete cluster.
#
#   vpc            -> network (subnets across AZs, NAT)
#   security       -> control plane + worker security groups
#   control_plane  -> the master node + EIP + Ansible inventory + autoscaler IAM
#   worker_pool    -> Launch Template + ASG (the campaign-burst autoscaling)
#
# Shared between control plane and workers:
#   aws_ssm_parameter.join_command  - master writes the kubeadm join command
#                                     here (via Ansible); workers read it on boot.
###############################################################################

locals {
  cluster_name = "${var.project}-${var.env}" # e.g. crm-dev
  name         = local.cluster_name

  tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

# Latest Ubuntu 22.04 image - same AMI for control plane and workers.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Register your SSH public key with AWS.
resource "aws_key_pair" "main" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
  tags       = local.tags
}

# SSM parameter that carries the kubeadm join command.
# Created with a placeholder; the control plane overwrites it (via Ansible)
# once "kubeadm init" has produced a real join command.
resource "aws_ssm_parameter" "join_command" {
  name  = "/${local.cluster_name}/k8s/join-command"
  type  = "SecureString"
  value = "PLACEHOLDER"
  tags  = local.tags

  lifecycle {
    ignore_changes = [value] # managed at runtime, not by Terraform
  }
}

# --- Modules ----------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.tags
}

module "security" {
  source = "../../modules/security"

  name                 = local.name
  vpc_id               = module.vpc.vpc_id
  ssh_allowed_cidr     = var.ssh_allowed_cidr
  api_allowed_cidr     = var.api_allowed_cidr
  ingress_allowed_cidr = var.ingress_allowed_cidr
  tags                 = local.tags
}

module "control_plane" {
  source = "../../modules/control-plane"

  name              = local.name
  cluster_name      = local.cluster_name
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.control_plane_instance_type
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security.control_plane_sg_id
  key_name          = aws_key_pair.main.key_name

  ssm_join_param_arn = aws_ssm_parameter.join_command.arn

  # DEV cost-saver: control plane doubles as the NAT instance for private workers.
  act_as_nat              = !var.enable_nat_gateway
  private_route_table_ids = module.vpc.private_route_table_ids

  ansible_inventory_path = "${path.module}/../../../ansible/inventory/${var.env}.ini"
  ssh_private_key_path   = var.ssh_private_key_path

  tags = local.tags
}

module "worker_pool" {
  source = "../../modules/worker-pool"

  name              = local.name
  cluster_name      = local.cluster_name
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.worker_instance_type
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security.worker_sg_id
  key_name          = aws_key_pair.main.key_name

  min_size         = var.worker_min_size
  max_size         = var.worker_max_size
  desired_capacity = var.worker_desired_capacity

  ssm_join_param_name = aws_ssm_parameter.join_command.name
  ssm_join_param_arn  = aws_ssm_parameter.join_command.arn
  k8s_version         = var.k8s_version
  region              = var.region

  tags = local.tags
}

# Managed PostgreSQL for the CRM app. The app's DB_HOST points here (the VPS
# host-Postgres trick has no AWS equivalent). RDS is independent of the EC2
# stop/start cost-saver - stopping the cluster does not touch the database.
module "rds" {
  source = "../../modules/rds"

  name       = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  allowed_security_group_ids = [
    module.security.worker_sg_id,
    module.security.control_plane_sg_id,
  ]

  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  instance_class = var.db_instance_class

  tags = local.tags
}
