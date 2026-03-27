# ADR 002: Single Node Pool (Merge Jobs Pool into Services)

## Status

Accepted

## Context

The cluster originally had two node pools:
- **services** — always-on, 1–2 nodes; runs all stateless services, ClickHouse, and Dagster daemon/webserver
- **jobs** — scale-to-zero, 0–2 nodes; tainted `workload=batch:NoSchedule`; runs only Dagster ETL batch jobs via `K8sRunLauncher`

The jobs pool was designed to scale from zero when a batch job was triggered, keeping costs near zero when idle. Dagster run pods had a hard node affinity for `scw-k8s-pool-name: jobs` and a toleration for the `workload=batch:NoSchedule` taint.

### The problem

Scaleway Kapsule's cluster autoscaler cannot reliably scale a tainted pool from zero. When the jobs pool has 0 nodes, the autoscaler creates a simulated node template to evaluate whether pending pods would fit. This template includes taints that don't match the pod's tolerations, so the autoscaler refuses to scale up:

```
pod didn't trigger scale-up:
  1 node(s) had untolerated taint(s),
  1 max node group size reached
```

The pod's toleration (`workload=batch:NoSchedule`) correctly matches the pool's configured taint, but the autoscaler's template simulation includes additional taints that the pod doesn't tolerate. This is a known class of issue with managed Kubernetes providers combining scale-from-zero with tainted node pools.

### Current workload

The cluster runs one daily ETL job (`cams_daily_job`). The services pool (1–2 nodes of BASIC2-A2C-8G, 2 vCPU / 8 GB each) has capacity to absorb this workload. The two-pool architecture adds operational complexity (taints, tolerations, node affinity, autoscaler template issues) that isn't justified at this scale.

### Options Considered

**Option A: Keep two pools, set `min_size = 1` on jobs pool**

- ✅ Fixes the immediate problem — a warm node is always available
- ✅ No changes to Dagster scheduling config
- ❌ Dedicated idle node costs ~€25/mo for a single daily job
- ❌ Retains the taint/toleration/affinity complexity
- ❌ Doesn't address the underlying autoscaler limitation — scaling from 1 to 2 could hit the same issue

**Option B: Keep two pools, remove the taint**

- ✅ Preserves scale-to-zero — autoscaler works without taint matching
- ✅ Node affinity still ensures run pods target the jobs pool
- ⚠️ Without taint, other pods (if unconstrained) could be scheduled on jobs nodes when the services pool is full
- ❌ Retains the two-pool complexity for marginal benefit at current scale

**Option C: Single pool**

- ✅ Eliminates the taint/toleration/affinity complexity entirely
- ✅ No autoscaler template issues — the pool always has at least 1 node
- ✅ Better resource utilization — services and batch jobs share capacity
- ✅ Autoscaler adds a node when batch jobs need capacity, removes it when idle — same cost model as before, but simpler
- ⚠️ No workload isolation between services and batch jobs — mitigated by resource requests/limits on all pods
- ⚠️ A resource-hungry batch job could compete with services on the same node — mitigated by autoscaler adding capacity

## Decision

Use a **single node pool** (the existing services pool) for all workloads. Bump `max_size` from 2 to 3 to give the autoscaler headroom for batch job capacity.

Remove the jobs pool resource from Terraform, and remove all taint/toleration/affinity configuration from the Dagster `K8sRunLauncher` config. Add resource requests to Dagster run pods so the scheduler and autoscaler can make informed placement and scaling decisions.

## Consequences

### Positive

- **Operational simplicity**: One pool, no taints, no tolerations, no node affinity rules. Fewer moving parts to debug when scheduling goes wrong.
- **Autoscaler reliability**: The pool always has at least 1 node, so the autoscaler never needs to simulate a template from zero. Scale-up from 1 to 2 (or 2 to 3) is well-tested.
- **Better utilization**: A batch job can use slack capacity on an existing node without waiting 2–3 minutes for a new node to provision. The autoscaler only adds a node if the existing ones are genuinely full.
- **Cost neutral**: Maximum cost is 3 nodes (~€75/mo) vs the previous maximum of 4 nodes (~€100/mo). Typical cost remains 1 node (~€25/mo).

### Negative

- **No workload isolation**: A CPU/memory-intensive batch job shares nodes with services. If the job exhausts node resources, services on the same node are affected. This is mitigated by setting resource requests and limits on all pods — the scheduler avoids overcommitting a node, and the kubelet enforces limits via cgroups.
- **Autoscaler cold-start still possible**: If all existing nodes are at capacity when a job is submitted, the autoscaler adds a node (2–3 min). This is the same delay the jobs pool had, but now it applies to the shared pool.

### When to revisit

Reintroduce a dedicated batch pool if:
- Multiple concurrent ETL jobs run regularly and compete for resources
- A pipeline needs significantly more CPU/memory than a BASIC2-A2C-8G node provides (requiring a different `node_type`)
- GPU or specialized hardware is needed for batch workloads
- Workload isolation becomes a compliance or reliability requirement

## References

- Node pool Terraform: `terraform/cluster.tf`
- Dagster run launcher config: `k8s/dagster/configmap.yaml`
- Previous pool architecture: ADR 001 (`docs/adr/001-arm64-node-instance-type.md`)
