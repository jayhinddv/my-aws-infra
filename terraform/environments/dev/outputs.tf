###############################################################################
# Environment outputs
###############################################################################

output "cluster_name" {
  value = local.cluster_name
}

output "control_plane_public_ip" {
  description = "Public IP of the control plane (kubectl/SSH endpoint)"
  value       = module.control_plane.public_ip
}

output "control_plane_private_ip" {
  value = module.control_plane.private_ip
}

output "ssh_command" {
  description = "SSH into the control plane"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${module.control_plane.public_ip}"
}

output "worker_asg_name" {
  description = "Worker Auto Scaling Group name"
  value       = module.worker_pool.asg_name
}

output "worker_scaling_bounds" {
  description = "Autoscaling bounds for the worker pool"
  value       = "min=${var.worker_min_size}, max=${var.worker_max_size}"
}

output "join_command_ssm_param" {
  description = "SSM parameter Ansible must populate with the kubeadm join command"
  value       = aws_ssm_parameter.join_command.name
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.endpoint
}

output "rds_host" {
  description = "RDS hostname - use this verbatim as DB_HOST in the app secret/configmap"
  value       = module.rds.address
}

output "rds_instance_id" {
  description = "RDS identifier (for scripts/stop.sh --with-rds)"
  value       = module.rds.instance_id
}

output "next_steps" {
  value = "1) terraform apply  2) run Ansible playbooks/cluster.yml (inits master, writes join cmd to SSM)  3) workers auto-join  4) deploy/deploy.sh (renders DB_HOST from rds_host, applies manifests)"
}
