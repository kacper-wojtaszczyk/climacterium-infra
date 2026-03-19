# ADR 001: ARM64 Node Instance Type (BASIC2-A2C-8G)

## Status

Accepted

## Context

Kapsule node pools require a minimum of 4 GB RAM per node. The cluster uses a single autoscaling pool (1–3 nodes) that runs all services and batch jobs (see [ADR 002](002-single-node-pool.md)).

The instance type chosen determines cost, architecture alignment, and operational characteristics across the entire deployment.

### Options Considered

**Option A: PLAY2-NANO** (x86_64, 2 vCPU, 4 GB RAM, ~€20/mo)

- ✅ Well-documented as a Kapsule-eligible node type
- ✅ Widely used in Scaleway tutorials — easy to find examples
- ❌ x86_64 architecture requires cross-compilation when building images on Apple Silicon (M-series Mac)
- ❌ Higher cost than equivalent ARM instances
- ❌ Development-tier instance - no SLA
- ❌ x86 server-class CPUs have worse performance-per-watt than modern ARM designs

**Option B: DEV1-M** (x86_64, 3 vCPU, 4 GB RAM — cheaper than PLAY2-NANO)

- ✅ Cheapest 4 GB option in nl-ams
- ❌ Development-tier instance — **not eligible for Kapsule node pools**
- ❌ Burstable/shared vCPUs, no production SLA
- ❌ Excluded from Kapsule's supported instance list

**Option C: BASIC2-A2C-8G** (ARM64 Ampere Altra, 2 vCPU, 8 GB RAM)

- ✅ Production-tier instance with SLA — eligible for Kapsule node pools
- ✅ Ampere Altra has significantly better performance-per-watt than x86 server CPUs — lower carbon footprint per workload
- ✅ Architecture alignment: developer machine (Apple Silicon M-series) and CI runner (GitHub `ubuntu-24.04-arm`) are both ARM64 — local builds, CI builds, and production nodes all target `linux/arm64` natively, with no cross-compilation at any stage
- ✅ All services (Go, Node.js, Python/Dagster, ClickHouse) have official ARM64 support
- ✅ 8GB RAM provides ample headroom for persistent services (~4GB at idle) plus batch job peaks
- ⚠️ Normally ARM64 images must be built explicitly — an `amd64`-only image fails on these nodes. This is mitigated by the architecture alignment above and enforced by the CI pipeline

## Decision

Use **BASIC2-A2C-8G** for the node pool.

The primary motivation is sustainability: Ampere Altra processors deliver substantially better performance per watt than equivalent x86 designs. For a project concerned with environmental data, running the infrastructure on more energy-efficient hardware is consistent with the project's values.

A secondary motivation is architecture alignment. I use an Apple Silicon Mac; CI runs on GitHub's ARM64 hosted runners (`ubuntu-24.04-arm`). With ARM64 Kapsule nodes, `docker build` on the developer's machine, the CI pipeline, and the production cluster all target the same `linux/arm64` architecture natively. There is no cross-compilation at any stage — no QEMU, no `--platform` flags in local builds, no architecture-specific "works on my machine" failure modes.

The cluster was initially deployed with BASIC2-A2C-4G (4GB RAM). Under real load, persistent services (ClickHouse, Dagster, jackfruit-api, buttprint-api, buttprint-fe) consume ~4GB at idle — leaving no headroom and the Dagster batch jobs also peak above 4GB. Upgraded to BASIC2-A2C-8G after observing this in production.

## Consequences

### Positive

- **Sustainability**: Lower energy consumption and carbon footprint per workload compared to x86 nodes
- **Architecture parity**: `docker build` locally (M-series Mac), in CI (ARM64 runner), and in production (BASIC2-A2C-8G) all produce identical `linux/arm64` images — no translation layer anywhere in the chain
- **Production SLA**: BASIC2 is a production-tier line, unlike DEV1; eligible for Kapsule and backed by Scaleway's uptime commitments

### Negative

- **Image discipline required**: Any third-party image used in the cluster must have an `linux/arm64` variant. Images that are `amd64`-only will fail to pull or run under QEMU with degraded performance. This must be verified when adding new components (e.g., sidecar containers, init containers)
- **Slightly less ecosystem documentation**: Most Scaleway Kapsule tutorials assume x86 nodes. ARM-specific quirks (e.g., native extension compilation in Python, architecture-specific system packages) require occasional extra research

### Mitigations

- **CI enforces the platform**: `docker/build-push-action` in `.github/workflows/deploy.yml` explicitly sets `platforms: linux/arm64`. A build that accidentally produces an `amd64` image will fail at the push step when the registry rejects the wrong manifest
- **Verified compatibility**: All services in this stack (Go binaries, Node.js/SvelteKit, Python/Dagster, ClickHouse 24.x, nginx Ingress Controller) have official `linux/arm64` images or native ARM64 binary builds

## References

- Infrastructure spec: `docs/buttprint-infrastructure.md`
- Node pool Terraform: `terraform/cluster.tf`
- CI pipeline: `.github/workflows/deploy.yml`
- Infra task guide for cluster provisioning: `docs/guides/infra-tasks/02-terraform-cluster.md`
- Infra task guide for containerisation: `docs/guides/infra-tasks/06-containerize-services.md`
