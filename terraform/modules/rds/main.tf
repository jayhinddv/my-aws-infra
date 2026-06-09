###############################################################################
# rds module - managed PostgreSQL for the CRM app.
#
# Lives in the PRIVATE subnets (never publicly reachable). Only the cluster
# nodes (worker + control-plane SGs) may open port 5432.
#
# This is what the app's DB_HOST points at, instead of the VPS host Postgres
# the docker/VPS manifests used (10.x CNI-bridge trick doesn't exist on AWS).
#
# Survives the cluster stop/start cost-saver: stopping EC2 does NOT touch RDS.
# If you want to pause RDS billing too, run scripts/stop.sh --with-rds, which
# stops the DB instance for up to 7 days (AWS auto-starts it after that).
###############################################################################

locals {
  common_tags = merge(var.tags, { Name = "${var.name}-rds" })
}

# --- Where RDS may live: the private subnets --------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-rds"
  subnet_ids = var.subnet_ids
  tags       = local.common_tags
}

# --- Security group: only the cluster nodes can reach 5432 ------------------
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "PostgreSQL for the CRM app - cluster nodes only"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-rds-sg" })
}

resource "aws_security_group_rule" "from_cluster" {
  for_each                 = toset(var.allowed_security_group_ids)
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = each.value
  description              = "PostgreSQL from cluster node SG"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  security_group_id = aws_security_group.rds.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

# --- The database -----------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # autoscale storage up to this
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-pg-final"

  # Password changes are managed out-of-band; ignore so a tfvars edit doesn't
  # force a disruptive update on every apply.
  lifecycle {
    ignore_changes = [password]
  }

  tags = local.common_tags
}
