# CLAUDE.md

This file provides guidance to Claude Code when working in the climacterium-infra repository.

## What This Is

Terraform + Kubernetes manifests for the all-Scaleway deployment of the [Buttprint](../docs/buttprint.md) ecosystem. This repo provisions and configures the infrastructure that all three application services run on:

```
Terraform (this repo)
  ├── VPC / Private Network
  ├── Kapsule cluster
  │   ├── services pool (1× BASIC2-A2C-4G, always-on)
  │   └── jobs pool (0-2× BASIC2-A2C-4G, scale-to-zero)
  ├── Managed PostgreSQL (DB-DEV-S)
  ├── Object Storage (jackfruit-raw bucket)
  ├── Container Registry (climacterium namespace)
  └── Load Balancer + DNS (buttprint.eu)

K8s manifests (this repo)
  ├── clickhouse (StatefulSet + PVC)
  ├── jackfruit-api (Deployment, ClusterIP only)
  ├── buttprint-api (Deployment + Ingress, public)
  ├── buttprint-fe (Deployment + Ingress, public)
  ├── dagster-daemon + dagster-webserver
  └── Secrets, ConfigMaps, Ingress rules
```

**Full spec:** [docs/buttprint-infrastructure.md](../../docs/buttprint-infrastructure.md)
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
├── providers.tf          ← Scaleway provider config
├── variables.tf          ← Input variables (project_id, region, zone)
├── networking.tf         ← VPC, Private Network
├── cluster.tf            ← Kapsule cluster, node pools
├── database.tf           ← Managed PostgreSQL
├── storage.tf            ← Object Storage bucket, IAM
├── registry.tf           ← Container Registry namespace
├── dns.tf                ← DNS zone + records (buttprint.eu)
├── outputs.tf            ← Kubeconfig, connection strings (sensitive)
└── terraform.tfvars      ← Variable values (gitignored)

k8s/
├── clickhouse/           ← StatefulSet + Service + PVC + ConfigMap
├── jackfruit-api/        ← Deployment + Service (ClusterIP)
├── buttprint-api/        ← Deployment + Service + Ingress
├── buttprint-fe/         ← Deployment + Service + Ingress
├── dagster/              ← Daemon + Webserver + ServiceAccount + RBAC
├── ingress/              ← nginx Ingress controller + LB config
└── secrets/              ← Secret templates (values not committed)

docs/
└── adr/                  ← Architecture Decision Records
```

## Infrastructure Architecture

### Cluster topology

- **Kapsule** with mutualized (free) control plane, Cilium CNI
- **Services pool:** 1-2× BASIC2-A2C-4G (ARM64, 2 vCPU, 4GB), always-on (`min=1, max=2`)
- **Jobs pool:** 0-2× BASIC2-A2C-4G, scale-to-zero, tainted `workload=batch:NoSchedule`
- ARM64 throughout — see [ADR 001](../docs/adr/001-arm64-node-instance-type.md)

### Managed services (same VPC, not in cluster)

- **PostgreSQL:** DB-DEV-S (~€8/mo), Private Network endpoint, dual-purpose (Dagster metadata + Jackfruit catalog)
- **Container Registry:** `climacterium` namespace, free up to 75GB. Endpoint: `rg.nl-ams.scw.cloud/climacterium/<image>:<tag>`
- **Object Storage:** `jackfruit-raw` bucket, S3-compatible API

### Networking

- Single VPC / Private Network spanning cluster + managed DB
- Pod-to-pod via cluster DNS (e.g. `jackfruit-api.default.svc.cluster.local:8080`)
- Pod-to-Postgres via Private Network endpoint (never public internet)
- One Scaleway Load Balancer (~€8/mo) + nginx Ingress controller (not per-service LBs)
- TLS: Scaleway managed TLS at the LB (auto Let's Encrypt)
- DNS: `buttprint.eu` registered at Scaleway, managed via Terraform

## Key Design Decisions

- **ARM64 nodes (ADR 001):** BASIC2-A2C-4G for both pools — sustainability (better perf/watt), architecture alignment (Apple Silicon dev → ARM64 CI → ARM64 prod), production SLA, cheaper than PLAY2-NANO
- **Single LB with Ingress:** One shared Load Balancer + nginx Ingress routes to multiple services by host/path — not per-service LBs
- **Local Terraform state:** `terraform.tfstate` stored locally for now. Migration to Scaleway Object Storage backend planned but not urgent
- **Private Network for DB/S3:** PostgreSQL endpoint on Private Network only. Object Storage accessed via S3 API (Scaleway-internal from pods)
- **Managed TLS at LB:** Let's Encrypt via Scaleway LB, not cert-manager in-cluster
- **ClickHouse as StatefulSet:** Not a Deployment — needs persistent storage (PVC) and stable network identity. `ReplacingMergeTree` engine
- **Dockerfiles live in service repos:** This repo contains only infrastructure. `jackfruit/`, `buttprint-api/`, `buttprint-fe/` each own their Dockerfile

## Terraform Conventions

- **Provider:** `scaleway/scaleway ~> 2.0` — check [Scaleway provider docs](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs) before writing HCL (breaking changes between versions)
- **Terraform version:** `>= 1.5`
- **File organization:** One file per resource type — `networking.tf`, `cluster.tf`, `database.tf`, `storage.tf`, `registry.tf`, `dns.tf`, `outputs.tf`
- **Sensitive outputs:** Mark all connection strings, credentials, and kubeconfig as `sensitive = true`
- **Variable defaults:** Region (`nl-ams`) and zone (`nl-ams-1`) have defaults. `project_id` has no default (must be provided via `terraform.tfvars`)
- **Naming pattern:** All Scaleway resources prefixed with `climacterium-` (e.g. `climacterium-cluster`, `climacterium-db`, `climacterium-registry`)
- **State is sacred:** Never delete `terraform.tfstate` manually. Never run `terraform destroy` without explicit intent

## Kubernetes Conventions

- **Manifests organized by service:** `k8s/<service>/` contains all resources for that service (Deployment, Service, Ingress, ConfigMap, etc.)
- **Resource requests and limits on all pods:** Every container must declare CPU/memory requests and limits
- **Health checks:** Liveness + readiness probes on all long-running pods
- **Secrets for credentials:** Never hardcode credentials in Deployment manifests. Use k8s Secrets (referenced via `envFrom` or `env[].valueFrom.secretKeyRef`)
- **StatefulSet for ClickHouse:** Not Deployment — PVC lifecycle is tied to the StatefulSet. Deleting a StatefulSet does not delete its PVCs
- **Taint/toleration for batch:** Jobs pool is tainted `workload=batch:NoSchedule`. Only pods with matching toleration land there (Dagster ETL jobs)
- **Image references:** `rg.nl-ams.scw.cloud/climacterium/<service>:<tag>` — always use the full registry path
