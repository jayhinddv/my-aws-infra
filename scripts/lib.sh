#!/usr/bin/env bash
###############################################################################
# Shared helpers for the cost-control scripts (stop/start/status).
#
# These pause/resume ONLY the billable compute, instead of terraform destroy +
# apply. Why that matters:
#   - The VPC, subnets, route tables, security groups and SSM param are FREE.
#     destroy/apply tears all of that down and rebuilds it (10-20 min, re-runs
#     kubeadm, loses all cluster state) just to avoid the one thing that costs
#     money per hour: the EC2 compute.
#   - Stopping the control-plane EC2 keeps its private IP (kubeadm/etcd certs
#     stay valid) and its Elastic IP (kubectl/SSH endpoint is unchanged), so it
#     comes back in ~40-60s with the cluster intact.
#   - Workers live in an ASG. You can't "stop" ASG members (the ASG relaunches
#     them), so we scale the group to 0 to terminate, and back to N to relaunch.
#     They're stateless, so re-joining is fine.
#
# Config via env (defaults match terraform/environments/dev):
#   PROJECT=crm  ENV=dev  REGION=ap-south-1
#   WORKER_MIN=1  WORKER_DESIRED=1   (what start.sh restores the ASG to)
###############################################################################
set -euo pipefail

PROJECT="${PROJECT:-crm}"
ENV="${ENV:-dev}"
REGION="${REGION:-ap-south-1}"
WORKER_MIN="${WORKER_MIN:-1}"
WORKER_DESIRED="${WORKER_DESIRED:-1}"

NAME="${PROJECT}-${ENV}"
ASG_NAME="${NAME}-worker-asg"
RDS_ID="${NAME}-pg"

aws() { command aws --region "$REGION" "$@"; }

# Echo the control-plane instance id (matched by tags, any non-terminated state).
control_plane_id() {
  aws ec2 describe-instances \
    --filters \
      "Name=tag:Project,Values=${PROJECT}" \
      "Name=tag:Environment,Values=${ENV}" \
      "Name=tag:k8s-role,Values=control-plane" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text
}

instance_state() {
  aws ec2 describe-instances --instance-ids "$1" \
    --query "Reservations[].Instances[].State.Name" --output text
}

rds_state() {
  aws rds describe-db-instances --db-instance-identifier "$RDS_ID" \
    --query "DBInstances[].DBInstanceStatus" --output text 2>/dev/null || echo "not-found"
}
