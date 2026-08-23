# CLAUDE.md

This file provides guidance to Claude Code when working in the climacterium-infra repository.

## What This Is

Terraform + Kubernetes manifests for the all-Scaleway deployment of the Buttprint ecosystem. This repo provisions and configures the infrastructure that all three application services run on:

```
Terraform (this repo)
  ├── VPC / Private Network
  ├── Kapsule cluster
  │   └── services pool (1-3× BASIC2-A2C-8G, autoscaling)
  ├── Object Storage (jackfruit-raw bucket)
  ├── Container Registry (climacterium namespace)
  ├── Load Balancer + DNS (buttprint.eu)
  └── Helm releases (ingress-nginx, k8s-monitoring)

K8s manifests (this repo)
  ├── postgres (StatefulSet + PVC)   ← in-cluster since INF-10 (was managed DB-DEV-S)
  ├── clickhouse (StatefulSet + PVC)
  ├── jackfruit-api (Deployment, ClusterIP only)
  ├── buttprint-api (Deployment + Ingress, public)
  ├── buttprint-fe (Deployment + Ingress, public)
  ├── dagster-daemon + dagster-webserver
  └── Secrets, ConfigMaps, Ingress rules
```


**Node type decision:** [docs/adr/001-arm64-node-instance-type.md](../docs/adr/001-arm64-node-instance-type.md)

## Commands

All Terraform commands run from the `terraform/` subdirectory:

```bash
# Terraform
cd terraform/
terraform init                        # Download providers + initialize state
terraform plan                        # Preview changes (dry run)
terraform apply                       # Apply changes to Scaleway
terraform destroy                     # Tear down all resources (destructive!)
terraform fmt                         # Format HCL files
terraform validate                    # Validate HCL syntax

# Kubectl (after cluster is provisioned)
kubectl get nodes                     # List cluster nodes
kubectl get pods -A                   # List all pods across namespaces
kubectl apply -f k8s/<service>/       # Apply manifests for a service
kubectl logs <pod>                    # View pod logs

# Scaleway CLI
scw k8s cluster list                  # List Kapsule clusters
scw rdb instance list                 # List managed databases

# Container Registry
docker login rg.nl-ams.scw.cloud/climacterium -u nologin --password-stdin <<< "$SCW_SECRET_KEY"
```

## Directory Structure

```
terraform/
├── providers.tf          ← Scaleway + ACME + Helm provider config
├── variables.tf          ← Input variables (project_id, region, zone, kubeconfig_path, secrets)
├── networking.tf         ← VPC, Private Network
├── cluster.tf            ← Kapsule cluster, node pools
├── storage.tf            ← Object Storage bucket, IAM
├── registry.tf           ← Container Registry namespace
├── dns.tf                ← DNS zone + records (buttprint.eu)
├── lb.tf                 ← Load Balancer + ACME TLS cert
├── helm.tf               ← helm_release resources (ingress-nginx, k8s-monitoring)
├── outputs.tf            ← Kubeconfig, connection strings (sensitive)
└── terraform.tfvars      ← Variable values (gitignored)

k8s/
├── ingress.yaml                  ← Ingress resource (host-based routing)
├── ingress-nginx-values.yaml.tpl ← Helm values template for nginx Ingress controller (rendered by terraform/helm.tf)
├── placeholder/                  ← Temporary placeholder (Task 05, replaced in Task 07)
├── postgres/                     ← StatefulSet + Service + init ConfigMap (in-cluster PG, INF-10)
├── clickhouse/                   ← StatefulSet + Service + PVC + ConfigMap
├── jackfruit-api/                ← Deployment + Service (ClusterIP)
├── buttprint-api/                ← Deployment + Service + Ingress
├── buttprint-fe/                 ← Deployment + Service + Ingress
├── dagster/                      ← Daemon + Webserver + ServiceAccount + RBAC
├── monitoring/                   ← Helm values template for k8s-monitoring (rendered by terraform/helm.tf)
└── secrets/                      ← Secret templates (values not committed)

docs/
└── adr/                  ← Architecture Decision Records
```

## Infrastructure Architecture

### Cluster topology

- **Kapsule** with mutualized (free) control plane, Cilium CNI
- **Single pool:** 1-3× BASIC2-A2C-8G (ARM64, 2 vCPU, 4GB), autoscaling (`min=1, max=3`). Runs all services and batch jobs — see [ADR 002](docs/adr/002-single-node-pool.md)
- ARM64 throughout — see [ADR 001](../docs/adr/001-arm64-node-instance-type.md)

### Managed services (same VPC, not in cluster)

- **Container Registry:** `climacterium` namespace, free up to 75GB. Endpoint: `rg.nl-ams.scw.cloud/climacterium/<image>:<tag>`
- **Object Storage:** `jackfruit-raw` bucket, S3-compatible API

(PostgreSQL is no longer managed — moved in-cluster in INF-10; see `k8s/postgres/` and ADR 003.)

### Networking

- Single VPC / Private Network (spans the cluster; the managed DB that used it was removed in INF-10)
- Pod-to-pod via cluster DNS (e.g. `jackfruit-api.default.svc.cluster.local:8080`)
- Pod-to-Postgres via cluster DNS (`postgres.default.svc.cluster.local:5432`) — in-cluster since INF-10
- One Scaleway Load Balancer (~€8/mo) + nginx Ingress controller (not per-service LBs)
- TLS: Let's Encrypt via ACME provider (DNS-01 challenge) → `scaleway_lb_certificate` (custom cert uploaded to LB). Cert renewal requires periodic `terraform apply`. Not auto-renewing — the ACME provider handles renewal when `min_days_remaining` threshold is reached during apply
- LB protocol: HTTP forwarding (`scw-loadbalancer-protocol-http: "*"`), not PROXY protocol. Real client IPs via X-Forwarded-For headers (`use-forwarded-headers: "true"` in nginx config)
- DNS: `buttprint.eu` registered at Scaleway, managed via Terraform

## Key Design Decisions

- **ARM64 nodes (ADR 001):** BASIC2-A2C-8G — sustainability (better perf/watt), architecture alignment (Apple Silicon dev → ARM64 CI → ARM64 prod), production SLA, cheaper than PLAY2-NANO
- **Single pool (ADR 002):** All workloads (services + batch jobs) share one autoscaling pool. No taints or node affinity — the autoscaler adds capacity when batch jobs need it
- **Single LB with Ingress:** One shared Load Balancer + nginx Ingress routes to multiple services by host/path — not per-service LBs
- **Local Terraform state:** `terraform.tfstate` stored locally for now. Migration to Scaleway Object Storage backend planned but not urgent
- **Private Network for S3/DB:** Object Storage accessed via S3 API (Scaleway-internal from pods). PostgreSQL moved in-cluster in INF-10 — no longer a Private Network endpoint
- **TLS at LB via ACME provider:** Let's Encrypt cert obtained via `vancluever/acme` provider (DNS-01 challenge through Scaleway DNS), uploaded to LB as `custom_certificate`. Not cert-manager in-cluster, not Scaleway's native `letsencrypt` block (which conflicts with CCM's port 80 frontend)
- **ClickHouse and PostgreSQL as StatefulSets:** Not Deployments — need persistent storage (PVC) and stable network identity. ClickHouse uses `ReplacingMergeTree`; PostgreSQL is in-cluster since INF-10 (ADR 003). Both single-replica, co-located on the base node
- **Helm releases managed by Terraform:** ingress-nginx and k8s-monitoring are provisioned via `helm_release` resources in `terraform/helm.tf`, not manual `helm install/upgrade`. Values files live as `.yaml.tpl` templates rendered by `templatefile()` so Terraform-derived IDs (LB ID, cert ID, Cockpit URL) propagate automatically. No manual chart installs in CI/CD — `terraform apply` is the single source of truth
- **Dockerfiles live in service repos:** This repo contains only infrastructure. `jackfruit/`, `buttprint-api/`, `buttprint-fe/` each own their Dockerfile

## Terraform Conventions

- **Provider:** `scaleway/scaleway ~> 2.0` — check [Scaleway provider docs](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs) before writing HCL (breaking changes between versions)
- **Terraform version:** `>= 1.5`
- **Providers:** `scaleway/scaleway ~> 2.0` + `vancluever/acme ~> 2.0` (TLS cert via DNS-01) + `hashicorp/helm ~> 3.0` (Helm release management)
- **File organization:** One file per resource type — `networking.tf`, `cluster.tf`, `storage.tf`, `registry.tf`, `dns.tf`, `lb.tf`, `helm.tf`, `outputs.tf`
- **Sensitive outputs:** Mark all connection strings, credentials, and kubeconfig as `sensitive = true`
- **Variable defaults:** Region (`nl-ams`) and zone (`nl-ams-1`) have defaults. `project_id` has no default (must be provided via `terraform.tfvars`). `kubeconfig_path` defaults to `~/.kube/config` — override per developer/CI in `terraform.tfvars` (the Helm provider does NOT honor `KUBECONFIG`, so this variable is the only way to point it at a non-default file)
- **State is sacred:** Never delete `terraform.tfstate` manually. Never run `terraform destroy` without explicit intent

## Kubernetes Conventions

- **Manifests organized by service:** `k8s/<service>/` contains all resources for that service (Deployment, Service, Ingress, ConfigMap, etc.)
- **Resource requests and limits on all pods:** Every container must declare CPU/memory requests and limits
- **Health checks:** Liveness + readiness probes on all long-running pods
- **Secrets for credentials:** Never hardcode credentials in Deployment manifests. Use k8s Secrets (referenced via `envFrom` or `env[].valueFrom.secretKeyRef`)
- **StatefulSet for ClickHouse and Postgres:** Not Deployment — PVC lifecycle is tied to the StatefulSet. Deleting a StatefulSet does not delete its PVCs
- **Image references:** `rg.nl-ams.scw.cloud/climacterium/<service>:<tag>` — always use the full registry path
- **Helm values as templates:** When a chart needs Terraform-derived values (LB IDs, cert IDs, push URLs), the values file lives at `k8s/<chart>-values.yaml.tpl` and is rendered via `templatefile()` from `terraform/helm.tf`. Hardcoded UUIDs in committed `.yaml`/`.yaml.tpl` files are a code smell — they go stale silently when the underlying Terraform resource is recreated

## Code Review

When reviewing PRs (automated or `@claude`-triggered):

- **Flag** hardcoded secrets or credentials in `.tf`/YAML, missing `sensitive = true` on outputs, missing resource requests/limits on pods, missing health probes, Scaleway provider quirks (zone on clusters, taints via tags), changes that force resource recreation without explicit intent, label/selector mismatches, `:latest` image tags, `helm_release` resources with unpinned `version` or missing `repository`, hardcoded Scaleway UUIDs in `.yaml.tpl` templates that should be `${var}` references
- **Skip** formatting (terraform fmt handles HCL), `.tfstate` contents, actual secret values in templates, pre-existing debt unrelated to the PR, cost optimization (documented in ADRs)
- **Verify** with `terraform -chdir=terraform fmt -check` and `terraform -chdir=terraform validate` before posting findings
- **Severity tags:** 🔴 must-fix, 🟡 nit, 🟣 pre-existing
