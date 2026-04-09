# Climacterium Infra

Terraform and Kubernetes manifests for deploying the Climacterium ecosystem on Scaleway Kapsule. Provisions a Kubernetes cluster (ARM64), managed PostgreSQL, S3-compatible object storage, container registry, load balancer with Let's Encrypt TLS, and DNS. Deploys all application services via K8s manifests.

## Architecture

```
Scaleway Kapsule (ARM64 Ampere Altra, autoscaling 1-3 nodes)
  ├── nginx Ingress + LB (TLS via Let's Encrypt / ACME DNS-01)
  ├── buttprint-api       (Deployment)
  ├── buttprint-fe        (Deployment)
  ├── jackfruit-api       (Deployment, ClusterIP — private network only)
  ├── clickhouse          (StatefulSet + PVC)
  └── dagster             (Daemon + Webserver)

Managed services (same VPC / Private Network):
  ├── PostgreSQL (Scaleway Managed)
  ├── Object Storage (S3-compatible)
  └── Container Registry
```

## Repository Structure

```
terraform/       IaC — one file per resource type
k8s/             Manifests — one directory per service
scripts/         Automation (Terraform outputs → K8s secrets)
docs/            ADRs
```

## Terraform

Providers: [`scaleway/scaleway`](https://registry.terraform.io/providers/scaleway/scaleway/latest) + [`vancluever/acme`](https://registry.terraform.io/providers/vancluever/acme/latest) (Let's Encrypt via DNS-01) + [`hashicorp/helm`](https://registry.terraform.io/providers/hashicorp/helm/latest) (ingress-nginx, k8s-monitoring).

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars  # Configure variables
terraform init
terraform plan
terraform apply
```

### Bootstrap order (clean apply from empty state)

The Helm releases in `helm.tf` require a running cluster **and** the `cockpit-credentials` Secret to exist before they can install. The secret is provisioned out-of-band by `scripts/sync-secrets.sh` (to keep sensitive values out of Terraform state), which creates a chicken-and-egg: you must bootstrap cluster → secrets → helm releases in separate steps.

```bash
cd terraform/

# 1. Cluster + node pool first (nothing in-cluster yet)
terraform apply -target=scaleway_k8s_cluster.main -target=scaleway_k8s_pool.services

# 2. Fetch kubeconfig so kubectl + sync-secrets.sh can reach the cluster
scw k8s kubeconfig install <cluster-id>

# 3. Create the cockpit-credentials Secret (referenced by the k8s-monitoring chart)
../scripts/sync-secrets.sh

# 4. Full apply — installs Helm releases and everything else
terraform apply
```

On steady-state re-applies (no teardown), `terraform apply` alone is sufficient. This dance is only needed on a from-zero rebuild.

## Kubernetes

Manifests in `k8s/`, organized by service directory. Ingress routes by hostname (`buttprint.eu` → FE, `api.buttprint.eu` → API, `dagster.buttprint.eu` → Dagster).

Secrets are synced from Terraform outputs via `scripts/sync-secrets.sh` — no credentials in manifests or version control.

## Related Repos

Part of the [Climacterium](https://github.com/kacper-wojtaszczyk?tab=repositories) ecosystem:

| Repo | Description |
|------|-------------|
| [jackfruit](https://github.com/kacper-wojtaszczyk/jackfruit) | Environmental data ingestion + serving (Go, Python, ClickHouse) |
| [buttprint-api](https://github.com/kacper-wojtaszczyk/buttprint-api) | Atmospheric scoring API + SVG butt generation (Go) |
| [buttprint-fe](https://github.com/kacper-wojtaszczyk/buttprint-fe) | Display layer (SvelteKit) |
