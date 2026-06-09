#!/usr/bin/env bash
###############################################################################
# status.sh - show whether the cluster's billable compute is up or paused.
#
# Usage:  ./status.sh
###############################################################################
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

echo "cluster: $NAME   region: $REGION"
echo

CP_ID="$(control_plane_id)"
if [[ -n "$CP_ID" ]]; then
  echo "control-plane : $CP_ID  [$(instance_state "$CP_ID")]"
else
  echo "control-plane : (none - destroyed?)"
fi

read -r MIN DES MAX < <(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]" --output text 2>/dev/null || echo "- - -")
RUNNING=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "length(AutoScalingGroups[0].Instances)" --output text 2>/dev/null || echo 0)
echo "workers (ASG) : min=$MIN desired=$DES max=$MAX  running=$RUNNING"

echo "rds           : $RDS_ID  [$(rds_state)]"
