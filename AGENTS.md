# Climacterium infrastructure

Terraform under terraform/; Kubernetes manifests under k8s/. Read relevant ADRs and the actual provider/chart pins before changes. Application Dockerfiles belong to service repositories.

- Never delete Terraform state. Apply, destroy, imports/state changes, cluster writes, and resource recreation require explicit task authorization; inspect the plan and target context before execution. Do not auto-approve infrastructure operations.
- Preserve persistent data/PVCs and check destructive effects separately from controller changes. Keep credentials out of tracked files and mark sensitive outputs appropriately.
- Follow existing resource requests/limits, probes, service boundaries, and pinned image/chart conventions. Confirm target architecture and available resources rather than assuming them.
- Terraform owns the existing Helm releases; do not create parallel manual Helm state. Keep Terraform-derived values in the existing templates/references, not copied resource IDs.
- Local checks: terraform -chdir=terraform fmt -check and terraform -chdir=terraform validate. State clearly if validation needs unavailable providers/init. Even planning can contact live services; do not treat it as an offline syntax check.
