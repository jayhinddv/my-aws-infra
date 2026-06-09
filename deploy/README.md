# Deploying the CRM app to the AWS cluster

The Terraform + Ansible in this repo build an empty kubeadm cluster. This folder
puts the **CRM app** on it. The manifests under [`manifests/`](manifests/) are
the VPS manifests from the main repo's `k8s/prod-vps/`, adapted for AWS:

| VPS (`k8s/prod-vps`)                              | AWS (`deploy/manifests`)                     |
| ------------------------------------------------- | -------------------------------------------- |
| `DB_HOST = 10.x` (CNI bridge → host Postgres)     | `DB_HOST = __DB_HOST__` → **RDS** endpoint   |
| namespace `crm-prod`                              | namespace `crm`                              |
| migrations owned by docker compose                | migrations run as a k8s Job (`migrate.yaml`) |
| `local-path` PVC storage class                    | default / `gp2` EBS storage class            |

Everything else (deployments, services, NodePorts 30901/30902, singletons) is
unchanged.

## One-time prerequisites

1. **Provision the cluster + database** (creates RDS too):
   ```bash
   export TF_VAR_db_password='a-strong-password'
   cd terraform/environments/dev && terraform apply
   cd ../../.. && ansible-playbook -i ansible/inventory/dev.ini ansible/cluster.yml
   ```

2. **Point kubectl at the cluster** — copy the kubeconfig off the control plane:
   ```bash
   eval "$(terraform -chdir=terraform/environments/dev output -raw ssh_command)"  # to inspect
   # or scp /etc/kubernetes/admin.conf and set KUBECONFIG to it
   ```

3. **Create the namespace + secrets** (these hold your credentials — not in git):
   ```bash
   kubectl create namespace crm

   # App env. Use your real .env, but make the DB_* match the RDS values you set
   # in terraform (DB_USER=crm, DB_NAME=crm, DB_PASSWORD=$TF_VAR_db_password).
   # DB_HOST is injected by deploy.sh, so it doesn't matter here.
   kubectl -n crm create secret generic backend-env --from-env-file=./.env.production

   # GHCR pull secret for the private images.
   kubectl -n crm create secret docker-registry ghcr-pull \
     --docker-server=ghcr.io --docker-username=<gh-user> --docker-password=<gh-PAT>
   ```

## Deploy / update

```bash
./deploy/deploy.sh
```

It reads the RDS host from `terraform output`, renders `__DB_HOST__`, runs the
migration Job, then rolls out the app and waits. Re-run it any time to push new
images (they're `imagePullPolicy: Always`, so a `kubectl rollout restart` or a
fresh `deploy.sh` pulls the latest tag).

## ⚠️ Public exposure — one wiring step still open

Workers live in **private subnets** (no public IP) and the **control-plane SG
does not open the NodePort range**. So the `NodePort` services (30901/30902)
are reachable *inside* the VPC but **not yet from the internet**. The VPS could
use NodePort directly because every node had a public IP; AWS here does not.

To actually serve traffic publicly, pick one (not done by this PR — it's a
networking decision):

- **Open the NodePorts on the control-plane SG** and run ingress-nginx there
  (simplest; control plane already has the Elastic IP). Add a rule for
  30000–32767 to `terraform/modules/security` control-plane SG.
- **Move workers to public subnets** (so their NodePorts are reachable), or
- **Front the cluster with an AWS Network/Application Load Balancer** pointing
  at the ingress-nginx NodePort.

ingress-nginx is already installed by the Ansible `addons` role, so once the
edge is reachable you can switch the Services to `ClusterIP` and add an Ingress.

## Pausing cost (instead of `terraform destroy`)

Don't destroy/recreate daily — just pause the compute. See
[`../scripts/`](../scripts/):

```bash
./scripts/stop.sh            # scale workers to 0 + stop control-plane EC2
./scripts/stop.sh --with-rds # also stop the database
./scripts/start.sh           # back up in ~1 min, cluster intact
./scripts/status.sh          # what's up / paused right now
```

The control plane keeps its Elastic IP and private IP across stop/start, so
nothing re-initialises and your kubeconfig keeps working.
