#!/usr/bin/env bash
###############################################################################
# start.sh - resume the cluster paused by stop.sh.
#
#   - starts the control-plane EC2 first (it's also the NAT for the workers,
#     so workers need it up before they can reach the internet to re-join)
#   - waits until it's running, then scales the worker ASG back up
#   - with --with-rds, starts the RDS database first of all
#
# The control plane keeps its Elastic IP and private IP across stop/start, so
# the cluster comes back intact - no kubeadm re-init, no kubeconfig change.
#
# Usage:  ./start.sh [--with-rds]
###############################################################################
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

WITH_RDS=0
[[ "${1:-}" == "--with-rds" ]] && WITH_RDS=1

if [[ "$WITH_RDS" == "1" ]]; then
  st="$(rds_state)"
  if [[ "$st" == "stopped" ]]; then
    echo "==> starting RDS instance $RDS_ID (takes a few minutes)"
    aws rds start-db-instance --db-instance-identifier "$RDS_ID" >/dev/null
  else
    echo "==> RDS $RDS_ID not in 'stopped' state (state: $st) - skipping"
  fi
fi

CP_ID="$(control_plane_id)"
if [[ -n "$CP_ID" ]]; then
  echo "==> starting control-plane instance $CP_ID"
  aws ec2 start-instances --instance-ids "$CP_ID" >/dev/null
  echo "    waiting for it to reach 'running'..."
  aws ec2 wait instance-running --instance-ids "$CP_ID"
  echo "    control plane is running"
else
  echo "ERROR: no control-plane instance found. If you ran 'terraform destroy'," >&2
  echo "       there is nothing to start - run 'terraform apply' instead." >&2
  exit 1
fi

echo "==> scaling worker ASG '$ASG_NAME' to min=$WORKER_MIN desired=$WORKER_DESIRED"
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --min-size "$WORKER_MIN" --desired-capacity "$WORKER_DESIRED" \
  && echo "    a worker will launch and re-join in ~2-3 min" \
  || echo "    (ASG not found - skipping)"

echo "==> done. Control plane up. Workers re-joining. Check with ./status.sh"
