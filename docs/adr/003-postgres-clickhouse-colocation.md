# ADR 003: PostgreSQL + ClickHouse Co-located on the Base Node

## Status

Accepted

## Context

INF-10 replaced the managed Scaleway `DB-DEV-S` PostgreSQL with an in-cluster
Postgres StatefulSet (`k8s/postgres/`). ClickHouse already runs as an in-cluster
StatefulSet (`k8s/clickhouse/`). Both are single-replica stateful workloads whose
`ReadWriteOnce` `scw-bssd` PVCs pin them to whichever node they first schedule on —
in practice the always-on base node (the pool's protected `min=1` node, per ADR 002).

So both of the platform's stateful stores now live on the **same** node. Before INF-10,
Postgres was managed and lived outside the cluster — a separate failure domain — so a
cluster node fault only affected ClickHouse.

### The trade-off

A single node fault (kernel panic, or node replacement during a Kubernetes upgrade or
an autohealing event) now takes **both** stateful workloads down at once, rather than one.

## Decision

Accept the co-location. Run in-cluster Postgres and ClickHouse on the shared base node,
with no second stateful node and no external managed database.

This is acceptable because both stores are **rebuildable derived caches**, not sources of
truth:

- S3 `jackfruit-raw` (immutable, append-only raw GRIB) is the sole source of truth, and
  the ETL is idempotent. ClickHouse `grid_data` rebuilds from S3 + ETL; the Postgres
  `catalog` schema likewise; Dagster run history is disposable. A node fault means "re-run
  the transforms," not "lose data."
- Traffic is low (hobby scale); a few minutes of downtime during a rare node-replacement
  event does not materially hurt.
- The base node is protected from autoscaler scale-down (ADR 002), so node replacement is
  rare — Kubernetes upgrades and autohealing, a few events per year.
- Co-location avoids the cost and complexity of a second stateful node or an external
  managed DB (the €11.85/mo INF-10 removed).

## Consequences

### Positive

- One failure domain to reason about; both stores restart from their PVCs when the node
  returns. No cross-node replica coordination.
- No recurring managed-DB cost; the in-cluster Postgres shares the base node's slack.

### Negative

- **Correlated failure**: one node fault downs both stores simultaneously.
- **No PG backups** (INF-10 fresh-start): recovery from PVC loss is a full ETL backfill
  from S3, not a restore. Dagster run history is not recoverable.
- **Shared RAM budget**: both StatefulSets now request memory on the base node (ClickHouse
  3Gi, Postgres 256Mi requests) — tracked against the INF-12 headroom budget.

### When to revisit

- Traffic grows enough that node-replacement downtime becomes user-impacting.
- PVC-loss recovery time (full backfill) becomes unacceptable → reintroduce durability
  (PG backups / WAL archiving) or move Postgres back to a separate failure domain.
- A second stateful node is justified for isolation.

## References

- In-cluster Postgres: `k8s/postgres/{statefulset,service,configmap-init}.yaml`
- ClickHouse: `k8s/clickhouse/{statefulset,service}.yaml`
- Base-node protection / single pool: ADR 002 (`docs/adr/002-single-node-pool.md`)
- PG password wiring: `terraform/variables.tf`, `scripts/sync-secrets.sh`
