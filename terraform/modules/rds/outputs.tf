###############################################################################
# rds module - outputs
###############################################################################

output "endpoint" {
  description = "host:port endpoint of the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname only (this is what DB_HOST should be)"
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "instance_id" {
  description = "RDS instance identifier (used by scripts/stop.sh --with-rds)"
  value       = aws_db_instance.this.identifier
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
