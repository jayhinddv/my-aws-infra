#!/usr/bin/env bash
###############################################################################
# deploy.sh - push the CRM app onto the AWS cluster.
#
# What it does:
#   1. reads the RDS hostname from terraform output (rds_host)
#   2. renders __DB_HOST__ in the manifests with that hostname (into a temp dir,
#      so the committed files stay as placeholders)
#   3. runs the DB migration Job and waits for it
#   4. applies the app manifests (kustomize) and waits for the rollouts
#
# Prereqs (created once, NOT by this script - they hold your secrets):
#   - kubectl context points at the AWS cluster (scp the kubeconfig from the
#     control plane, or use `terraform output ssh_command`)
#   - namespace + secrets exist:
#       kubectl create namespace crm
#       kubectl -n crm create secret generic backend-env --from-env-file=/path/to/.env.production
#       kubectl -n crm create secret docker-registry ghcr-pull \
#         --docker-server=ghcr.io --docker-username=<gh-user> --docker-password=<gh-PAT>
#     NOTE: the .env you load must already have the RDS DB_USER/DB_PASSWORD/DB_NAME.
#           Only DB_HOST is injected by this script (from terraform).
#
# Usage:
#   ./deploy.sh             # uses terraform/environments/dev
#   TF_DIR=../terraform/environments/prod ./deploy.sh
###############################################################################
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-$HERE/../terraform/environments/dev}"
NS="${NS:-crm}"
SRC="$HERE/manifests"

echo "==> reading RDS host from terraform ($TF_DIR)"
DB_HOST="$(terraform -chdir="$TF_DIR" output -raw rds_host)"
if [[ -z "$DB_HOST" || "$DB_HOST" == "__DB_HOST__" ]]; then
  echo "ERROR: could not read rds_host from terraform output. Run 'terraform apply' first." >&2
  exit 1
fi
echo "    DB_HOST = $DB_HOST"

# Fail early if the secrets aren't there - applying without them just crash-loops.
for s in backend-env ghcr-pull; do
  if ! kubectl -n "$NS" get secret "$s" >/dev/null 2>&1; then
    echo "ERROR: secret '$s' missing in namespace '$NS'. See the prereqs in this script's header." >&2
    exit 1
  fi
done

# Render into a temp dir so the committed manifests keep their __DB_HOST__ marker.
RENDER="$(mktemp -d)"
trap 'rm -rf "$RENDER"' EXIT
cp "$SRC"/*.yaml "$RENDER"/
sed -i "s|__DB_HOST__|${DB_HOST}|g" "$RENDER"/backend.yaml "$RENDER"/migrate.yaml

echo "==> running DB migration job"
kubectl -n "$NS" delete job/migrate --ignore-not-found
kubectl apply -f "$RENDER/migrate.yaml"
kubectl -n "$NS" wait --for=condition=complete job/migrate --timeout=300s

echo "==> applying app manifests"
kubectl apply -k "$RENDER"

echo "==> waiting for rollouts"
for d in backend frontend python-svc cron email-scheduler redis; do
  kubectl -n "$NS" rollout status deploy/"$d" --timeout=180s
done

echo "==> done. Services:"
kubectl -n "$NS" get svc -o wide
