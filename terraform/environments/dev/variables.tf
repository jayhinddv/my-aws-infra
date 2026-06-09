###############################################################################
# Environment input variables (values come from dev.tfvars)
###############################################################################

variable "project" {
  description = "Project name"
  type        = string
  default     = "crm"
}

variable "env" {
  description = "Environment name (dev/prod) - also used for the inventory filename"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

# --- Network ----------------------------------------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones (1 for dev, 2-3 for prod HA)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  description = "true = managed NAT gateway (prod). false = no NAT GW; route private subnets through the control-plane NAT instance (dev, free)."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When enable_nat_gateway = true: true = cheap shared NAT, false = NAT per AZ (prod HA)"
  type        = bool
  default     = true
}

# --- Compute ----------------------------------------------------------------
variable "control_plane_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "worker_instance_type" {
  type    = string
  default = "t3.small"
}

variable "worker_min_size" {
  description = "Baseline worker count"
  type        = number
  default     = 1
}

variable "worker_max_size" {
  description = "Campaign peak worker count"
  type        = number
  default     = 3
}

variable "worker_desired_capacity" {
  type    = number
  default = 1
}

variable "k8s_version" {
  type    = string
  default = "1.30"
}

# --- Access control ---------------------------------------------------------
variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH. Lock to your IP/32 in prod."
  type        = string
}

variable "api_allowed_cidr" {
  description = "CIDR allowed to reach the K8s API (kubectl)."
  type        = string
}

variable "ingress_allowed_cidr" {
  description = "CIDR allowed to reach the app (NodePort range)."
  type        = string
  default     = "0.0.0.0/0"
}

# --- SSH keys ---------------------------------------------------------------
variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/crm_dev_ed25519.pub"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/crm_dev_ed25519"
}

# --- Database (RDS PostgreSQL) ----------------------------------------------
variable "db_name" {
  type    = string
  default = "crm"
}

variable "db_username" {
  type    = string
  default = "crm"
}

variable "db_password" {
  description = "RDS master password. Provide via TF_VAR_db_password env var (preferred) or a non-committed secrets tfvars - never hardcode in dev.tfvars."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
