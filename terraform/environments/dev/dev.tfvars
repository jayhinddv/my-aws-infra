###############################################################################
# DEV environment values - small and cheap
###############################################################################

project = "crm"
env     = "dev"
region  = "ap-south-1"

# --- Network: single AZ, NO NAT gateway (control plane acts as NAT = free) ---
vpc_cidr             = "10.20.0.0/16"
azs                  = ["ap-south-1a"]
public_subnet_cidrs  = ["10.20.1.0/24"]
private_subnet_cidrs = ["10.20.11.0/24"]
enable_nat_gateway   = false # workers reach the internet via the control-plane NAT instance
single_nat_gateway   = true  # ignored when enable_nat_gateway = false

# --- Compute (free-tier-eligible x86 types) ---
# t3.small = 2 GB = kubeadm's minimum for the control plane.
# If the control plane feels tight, switch to "m7i-flex.large" (8 GB, also free-tier eligible).
control_plane_instance_type = "t3.small"
worker_instance_type        = "t3.small"
worker_min_size             = 1
worker_max_size             = 2
worker_desired_capacity     = 1
k8s_version                 = "1.30"

# --- Access (TODO: lock these to your IP/32 instead of 0.0.0.0/0) ---
ssh_allowed_cidr     = "0.0.0.0/0"
api_allowed_cidr     = "0.0.0.0/0"
ingress_allowed_cidr = "0.0.0.0/0"

# --- SSH keys ---
ssh_public_key_path  = "~/.ssh/crm_dev_ed25519.pub"
ssh_private_key_path = "~/.ssh/crm_dev_ed25519"

# --- Database (RDS PostgreSQL) ---
# db_password is intentionally NOT stored here. Set it before apply:
#   export TF_VAR_db_password='your-strong-password'
db_name           = "prod_crm"
db_username       = "vi_admin"
db_instance_class = "db.t3.micro" # free-tier eligible
