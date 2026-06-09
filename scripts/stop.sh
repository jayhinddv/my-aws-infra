#!/usr/bin/env bash
###############################################################################
# stop.sh - pause the cluster's billable compute (NOT a destroy).
#
#   - scales the worker ASG to 0 (terminates worker instances)
#   - stops the control-plane EC2 instance
#   - with --with-rds, also stops the RDS database (AWS auto-starts it after 7d)
#
# Resume with start.sh - comes back in under a minute, cluster state intact.
#
# Usage:  ./stop.sh [--with-rds]
###############################################################################
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

WITH_RDS=0
[[ "${1:-}" == "--with-rds" ]] && WITH_RDS=1

echo "==> scaling worker ASG '$ASG_NAME' to 0"
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name "$ASG_NAME" \
  --min-size 0 --desired-capacity 0 \
  && echo "    workers will terminate shortly" \
  || echo "    (ASG not found - skipping)"

CP_ID="$(control_plane_id)"
if [[ -n "$CP_ID" ]]; then
  echo "==> stopping control-plane instance $CP_ID"
  aws ec2 stop-instances --instance-ids "$CP_ID" >/dev/null
  echo "    stop requested (state: $(instance_state "$CP_ID"))"
else
  echo "==> no control-plane instance found - skipping"
fi

if [[ "$WITH_RDS" == "1" ]]; then
  st="$(rds_state)"
  if [[ "$st" == "available" ]]; then
    echo "==> stopping RDS instance $RDS_ID"
    aws rds stop-db-instance --db-instance-identifier "$RDS_ID" >/dev/null
    echo "    stop requested"
  else
    echo "==> RDS $RDS_ID not stoppable (state: $st) - skipping"
  fi
fi

echo "==> done. Billable compute paused. Resume with ./start.sh"
