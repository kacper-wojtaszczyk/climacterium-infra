# Climacterium Infra

Terraform and Kubernetes manifests for deploying Climacterium on Scaleway Kapsule. Terraform manages the cluster, a reserved routed IPv4 address, DNS, object storage, registry, and the ingress-nginx, cert-manager, and monitoring Helm releases. Kubernetes manifests deploy the application services, PostgreSQL and ClickHouse.

## Architecture

```
Scaleway Kapsule (services pool autoscaling 1–3 nodes)
  ├── ingress-nginx (DaemonSet on the labeled node, ports 80/443; TLS via cert-manager)
  ├── buttprint-api, buttprint-fe, jackfruit-api (private ClusterIP)
  ├── PostgreSQL, ClickHouse (StatefulSets + PVCs)
  └── Dagster daemon + on-demand webserver

Scaleway Object Storage (jackfruit-raw) + Container Registry
```

The reserved IPv4 address and the pool's 80/443-only inbound security group are managed by Terraform, but **Kapsule node attachment is an operational CLI step**: the Scaleway provider does not accept `server_id` on `scaleway_instance_ip`. An ordinary `terraform apply` does not attach or reattach the IP. Kapsule's node image has no `scw-net-reconfig` unit; the ingress DaemonSet's `NET_ADMIN` init container adds the routed /32 to the labeled node's public `enp0s1` interface before nginx starts. This is a single-node ingress design, not high availability. See the runbook below for both the CLI attachment and node label.

## Repository structure

```
terraform/       IaC and Helm releases
k8s/             Service manifests, ingress, and the local buttprint-tls Helm chart
scripts/         Automation (Terraform outputs → K8s Secrets)
docs/            ADRs
```

## Terraform

Providers: [`scaleway/scaleway`](https://registry.terraform.io/providers/scaleway/scaleway/latest) and [`hashicorp/helm`](https://registry.terraform.io/providers/hashicorp/helm/latest). cert-manager manages Let's Encrypt certificates in-cluster. The old Terraform ACME provider was removed after its resources were cleaned up. The optional `scw_secret_key` input remains for compatibility with existing untracked local `terraform.tfvars`; it is not used by the current config.

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars # configure variables (local file, not committed)
terraform init
terraform plan
terraform apply
```

For a clean bootstrap, create the cluster and pool first, install the kubeconfig, then run `../scripts/sync-secrets.sh` before the full `terraform apply` (k8s-monitoring needs `cockpit-credentials`). The full apply installs cert-manager, ingress-nginx, and then the local `buttprint-tls` Helm release (`k8s/cert-manager/`) with the ACME contact email from `var.acme_email`. Deploy the application and `k8s/ingress.yaml` separately using their normal manifest/deployment workflow. Before installing ingress-nginx, label one Ready pool node `ingress.buttprint.eu/active=true`. Attach the reserved IP using the runbook below. Never switch DNS to it until direct HTTP is reachable.

## INF-09: LB → direct ingress cutover (completed 2026-10-08)

The migration is complete on the existing cluster. The sequence below records how it was performed; do not repeat the targeted applies on a steady-state cluster. Kapsule did not detach the additional IP during the cutover, but behavior after a future node replacement has not been tested.

From `terraform/`, with the existing kubeconfig and Scaleway CLI configured:

1. `terraform plan` — inspect *all* proposed changes. The additional routed IPv4 is billed separately from the node's existing IPv4; net savings will be **less than the old €20.84/month LB line**, with actual spend pending billing.
2. `terraform apply -target=scaleway_instance_ip.ingress -target=helm_release.cert_manager` — reserve an IP and install cert-manager without changing DNS or the existing ingress. Read the IP and ID using `terraform output -raw ingress_flexible_ip` and `terraform output -raw ingress_flexible_ip_id`. Verify the deployments in `cert-manager` are Available.
3. Pick a Ready node in the `services` pool with `kubectl get nodes -o wide`; use `.spec.providerID` for its Instance UUID and zone. Attach the reserved IP with `scw instance server update` and `public-ips.N=<ID>` arguments, passing **all** existing IPv4 and IPv6 IDs as well as the new ID. Verify the original IP remains. Label the node `kubectl label node <NODE_NAME> ingress.buttprint.eu/active=true`. Kapsule retained the second IP across repeated checks during the migration.
4. Apply the pool's new Terraform security group and ingress controller (`terraform apply -target=scaleway_k8s_pool.services`, then `terraform apply -target=helm_release.ingress_nginx`). The old `LoadBalancer` Service becomes `ClusterIP`, ingress-nginx runs on the labeled node's host network, and its init container configures the additional /32 on `enp0s1`. Verify the DaemonSet is Ready and use `curl --resolve buttprint.eu:80:<RESERVED_IP> -I http://buttprint.eu/` to test port 80 directly. The default Kapsule security group blocks inbound 80/443, and without guest /32 configuration the new address times out. Changing the Service interrupts the old route before Terraform deletes the old LB.
5. Apply `k8s/ingress.yaml` with TLS `secretName: buttprint-tls`, then `terraform apply -target=scaleway_domain_record.root -target=scaleway_domain_record.api -target=scaleway_domain_record.dagster -target=helm_release.buttprint_tls` to switch DNS and create the issuer/certificate. Wait for DNS propagation and `kubectl get certificate,challenge -A` to show Ready. Three-host SAN issuance succeeded using Let's Encrypt production HTTP-01.
6. Verify FE 200, API `/health` 204, and Dagster Basic Auth 401 when the webserver is scaled to 1; scale it back to zero afterwards. The first full Terraform apply could not remove the LB certificate while a stale frontend still referenced it. `terraform apply -target=scaleway_lb.main` removed the old LB first; a subsequent full `terraform apply` deleted its IP and the old ACME resources. The legacy ACME provider was then removed from the config. Verify that the final plan is empty and confirm the old LB is gone in Scaleway CLI. External TLS grading and actual billing savings remain to be verified separately.

cert-manager stores its ACME account key and TLS keypair as Kubernetes Secrets; there is no configured backup. A cluster rebuild may require reissuing certificates (Let's Encrypt rate limits apply).

## Kubernetes

Ingress routes by hostname (`buttprint.eu` → FE, `api.buttprint.eu` → API, `dagster.buttprint.eu` → Dagster). The `buttprint-tls` Certificate is one SAN certificate covering all three and resides in `default`, where all three Ingress objects reference its Secret. cert-manager uses Let's Encrypt production HTTP-01 on port 80; port 443 is terminated at ingress-nginx. With no trusted upstream proxy, nginx does not trust client-supplied forwarding headers. The ingress-nginx admission webhook is disabled: with `hostNetwork` on Kapsule its node-IP endpoint was unreachable from the API server, blocking Ingress updates. Check changes with `kubectl apply --dry-run=server -f k8s/ingress.yaml` and monitor nginx logs after applying; this does not replicate the old webhook's nginx-specific validation.

Secrets are synced from Terraform outputs via `scripts/sync-secrets.sh` where applicable; no credentials are committed in manifests.

## Runbook: Re-attach the reserved IP after node replacement

Kapsule autoscaling retains at least one node (`min_size=1`), **not a particular node identity**. Autohealing, upgrades, or replacements can remove the IP's host; no automatic failover is configured and availability depends on noticing and moving the IP. DNS continues to point to the reserved IP (TTL 300); moving that *same* IP does not require a DNS change. The number and duration of replacements cannot be guaranteed.

1. `kubectl get nodes -o wide` — find a Ready node in the `services` pool; inspect `.spec.providerID` for its Instance UUID and zone. Do not assume `nodes[0]` or the oldest node is the base node.
2. `terraform -chdir=terraform output -raw ingress_flexible_ip_id` and `terraform -chdir=terraform output -raw ingress_flexible_ip` — identify the reserved IP. Check `scw instance server get <SERVER_ID> zone=<ZONE>` and `scw instance ip list zone=<ZONE>` to identify all currently assigned IP IDs. If attached to a surviving old node, detach it first using the CLI while preserving that node's other IPs.
3. With `scw instance server update --help`, attach the reserved IP using `public-ips.0=<EXISTING_IPV4_ID> public-ips.1=<EXISTING_IPV6_ID> public-ips.2=<RESERVED_IP_ID> zone=<ZONE>` (adjust to the *complete* set of the new node's public IPs). Preserve its original IP; removing it could break Kapsule's access to the node. Verify the Instance lists the new IP as attached. Do not change DNS or Terraform's IP resource.
4. Remove `ingress.buttprint.eu/active` from the old node if it still exists, then `kubectl label node <NEW_NODE_NAME> ingress.buttprint.eu/active=true`. Verify the ingress-nginx DaemonSet is Ready on the new node and its init container has added the reserved /32 to the public interface (`enp0s1` on the current node). Check HTTPS using `curl --resolve buttprint.eu:443:<RESERVED_IP> -I https://buttprint.eu/`, then `kubectl get certificate,challenge -A`. If the IP disappears again or the interface name differs, fix the underlying setup rather than repeatedly reattaching it.

No web console is required. IP attachment is not expressed as a Terraform resource, so its success must be checked after a node replacement.

## Runbook: On-demand Dagster UI

The Dagster webserver is declared at `replicas: 0` (INF-12). The daemon handles scheduling and execution independently. Bring up the UI only when needed:

```bash
kubectl scale deployment/dagster-webserver --replicas=1
kubectl rollout status deployment/dagster-webserver --timeout=120s
kubectl port-forward svc/dagster-webserver 3000:3000
# Open http://localhost:3000; stop port-forward when finished
kubectl scale deployment/dagster-webserver --replicas=0
```

The basic-auth-protected `https://dagster.buttprint.eu` route also works once the pod is Ready. Scaling up is temporary: the next `kubectl apply -f k8s/dagster/` resets the declared replica count to zero. Dagster's Postgres run history remains available to the UI on startup.

## Related repos

| Repo | Description |
|------|-------------|
| [jackfruit](https://github.com/kacper-wojtaszczyk/jackfruit) | Environmental data ingestion + serving (Go, Python, ClickHouse) |
| [buttprint-api](https://github.com/kacper-wojtaszczyk/buttprint-api) | Atmospheric scoring API + SVG rendering (Go) |
| [buttprint-fe](https://github.com/kacper-wojtaszczyk/buttprint-fe) | Display layer (SvelteKit) |
