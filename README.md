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

Providers: [`scaleway/scaleway`](https://registry.terraform.io/providers/scaleway/scaleway/latest) + [`vancluever/acme`](https://registry.terraform.io/providers/vancluever/acme/latest) (Let's Encrypt via DNS-01).

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars  # Configure variables
terraform init
terraform plan
terraform apply
```

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
