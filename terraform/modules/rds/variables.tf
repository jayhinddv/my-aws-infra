###############################################################################
# rds module - input variables
###############################################################################

variable "name" {
  description = "Name prefix (e.g. crm-dev)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (need >= 2 AZs for RDS, even single-AZ instances)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach 5432 (worker + control-plane SGs)"
  type        = list(string)
}

variable "db_name" {
  type    = string
  default = "crm"
}

variable "db_username" {
  type    = string
  default = "crm"
}

variable "db_password" {
  description = "Master password. Set via TF_VAR_db_password or a non-committed *.tfvars - do NOT hardcode in dev.tfvars."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro" # free-tier eligible
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling. 0 disables autoscaling."
  type        = number
  default     = 50
}

variable "multi_az" {
  type    = bool
  default = false # dev: single-AZ to stay cheap
}

variable "backup_retention_period" {
  type    = number
  default = 1 # dev: keep 1 day of backups
}

variable "deletion_protection" {
  type    = bool
  default = false # dev: allow terraform destroy
}

variable "skip_final_snapshot" {
  type    = bool
  default = true # dev: don't snapshot on destroy
}

variable "tags" {
  type    = map(string)
  default = {}
}
