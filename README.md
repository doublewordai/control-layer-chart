# Control Layer Helm Chart

A standalone Helm chart for deploying the Doubleword control layer service.

## Overview

This chart deploys the control layer service, which includes:

- Deployment with configurable replicas
- Service for internal cluster communication
- ConfigMap for application configuration
- Secret for database credentials
- Optional ServiceMonitor for Prometheus metrics

## Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

### Install from OCI Registry

```bash
helm install my-control-layer oci://ghcr.io/doublewordai/charts/control-layer
```

You can also provide custom values:

```bash
helm install my-control-layer oci://ghcr.io/doublewordai/charts/control-layer -f custom-values.yaml
```

## Configuration

### Externally managed runtime Secret

By default the chart creates `<release>-control-layer-secret` from
`secrets.controlLayer.data`. To use a Secret managed by another controller,
configure its name instead:

```yaml
secrets:
  controlLayer:
    existingSecret: externally-managed-runtime
```

The named Secret must exist in the release namespace and contain
`DATABASE_URL` plus any other runtime keys required by the deployment. The
chart does not render or mutate a Secret when `existingSecret` is set, and both
the application and Fusillade workloads consume the same name.

For a small credential that rotates independently, keep the chart-owned Secret
and load one or more overlays after it:

```yaml
secrets:
  controlLayer:
    extraExistingSecrets:
      - rotated-database
```

Kubernetes resolves duplicate `envFrom` keys from the later Secret, so overlays
should contain only the keys they intentionally replace.

The following table lists the configurable parameters and their default values. See `values.yaml` for all available options.

### Core Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/doublewordai/control-layer` |
| `image.tag` | Container image tag | Chart appVersion |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `3001` |

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccountName` | Name of existing service account to use | `""` |

If you want to use a specific service account, set `serviceAccountName`. Otherwise, pods will use the default service account.

### Database Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.controlLayer.create` | Create secret for database credentials | `true` |
| `secrets.controlLayer.name` | Name of existing secret (if not creating) | `""` |
| `secrets.controlLayer.data.DATABASE_URL` | Database connection string | `""` (auto-generated if postgresql.enabled) |
| `postgresql.enabled` | Whether PostgreSQL is enabled in parent chart | `true` |
| `secrets.postgres.data.POSTGRES_DB` | PostgreSQL database name | `clay` |
| `secrets.postgres.data.POSTGRES_USER` | PostgreSQL user | `clay` |
| `secrets.postgres.data.POSTGRES_PASSWORD` | PostgreSQL password | `clay_password` |

The chart supports both internal and external PostgreSQL databases:

- **Internal PostgreSQL**: If `postgresql.enabled: true`, the DATABASE_URL will be auto-generated using the postgres secret values
- **External PostgreSQL**: Set `secrets.controlLayer.data.DATABASE_URL` to your external connection string and `postgresql.enabled: false`

### Monitoring

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Enable Prometheus ServiceMonitor | `false` |
| `serviceMonitor.path` | Metrics endpoint path | `/metrics` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |
| `serviceMonitor.labels` | Additional labels for ServiceMonitor | `{}` |

### Application Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config` | Control layer application configuration (YAML) | See values.yaml |
| `env` | Additional environment variables | `{}` |

### Resources and Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `livenessProbe` | Liveness probe configuration | HTTP GET /healthz |
| `readinessProbe` | Readiness probe configuration | HTTP GET /healthz |

### Pod Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Annotations to add to pods | `{}` |
| `podLabels` | Labels to add to pods | `{}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Container security context | `{}` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `volumes` | Additional volumes | `[]` |
| `volumeMounts` | Additional volume mounts | `[]` |

### Graceful rollouts

Long-running request handlers can be preserved during a Deployment rollout by
enabling the opt-in rollout contract:

```yaml
rollout:
  enabled: true
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  endpointDrainDelaySeconds: 15
  connectionDrainTimeoutSeconds: 3600
  terminationGracePeriodSeconds: 3700
  minReadySeconds: 15
  progressDeadlineSeconds: 4200
```

Kubernetes first marks the old Pod endpoint as terminating. The `preStop`
delay keeps the process alive while Service and ingress routing converge, after
which the control layer receives `SIGTERM` and uses its application-level
graceful shutdown path. The termination grace supports requests lasting up to
`connectionDrainTimeoutSeconds`, with additional time for endpoint propagation
and cleanup. Keep `connectionDrainTimeoutSeconds` at `3600`: it mirrors the
application's fixed maximum request wait and is validated rather than passed to
the process as runtime configuration.

`maxUnavailable: 0` and `maxSurge: 1` temporarily require capacity for one
extra control-layer Pod. These settings apply only to the request-serving
Deployment; Fusillade workers retain their independent shutdown and recovery
behavior.

The progress deadline must be greater than the termination grace, and the
termination grace must be greater than the endpoint drain delay. The chart
rejects enabled configurations that violate either requirement.

### Heap profiling (diagnostic)

The opt-in heap profiler renders one extra API Deployment
(`<fullname>-heap-profile`) that samples the dwctl (Rust) heap with jemalloc and serves
`GET /debug/pprof/heap` (gzipped pprof) on a dedicated port. The canary carries
the API Service selector labels, so it receives normal API traffic (the point is
to observe real load), but it is a separate Deployment with the
`control-layer.doubleword.ai/diagnostic: heap-profile` label in its own
selector, and it never touches the main Deployment's pods. The pprof listener is
**never** added to a Service, Ingress or ServiceMonitor endpoint.

```yaml
heapProfiling:
  enabled: true
  replicas: 1
  lgProfSample: 19        # mean sample interval 2^N bytes (19 = 512 KiB)
  port: 6060              # containerPort named "pprof"; not in any Service
  scrapeAnnotations: true # Alloy profiles.grafana.com/memory.* annotations
  serviceName: ""         # Pyroscope service_name; default "<fullname>-api"
  podLabels: {}
  podAnnotations: {}
  env: {}                 # extra env for this pod only, merged last
  resources: {}           # defaults to the top-level `resources`
  networkPolicy:
    enabled: false
    from: []              # NetworkPolicyPeer list for the pprof port
```

**Overhead.** Sampling only starts when `_RJEM_MALLOC_CONF` includes
`prof:true,prof_active:true` at process start; the chart injects
`prof:true,prof_active:true,lg_prof_sample:<N>`. At the default `2^19`
(512 KiB) mean sample interval, CPU overhead scales with the bytes the pod
allocates and depends on the workload: an allocation-only benchmark measured
roughly 45–50% more CPU, and a service that spends little time in the
allocator sees much less. Memory grows by a few MiB of sampling metadata plus
roughly 33 MiB of symbolizer cache after the first dump. Size the canary's
resources accordingly, measure it against its peers in staging, and keep it
for diagnostic windows rather than permanent operation. See the control-layer
`docs/memory-observability.md` for the measurements.

**Enable / disable.** Set `heapProfiling.enabled: true` to render the
Deployment and `false` (the default) to remove it on the next sync. The chart
also sets `DWCTL_HEAP_PROFILING__ENABLED=true` and
`DWCTL_HEAP_PROFILING__BIND_ADDRESS=0.0.0.0:<port>` on the canary only.

**Capture a profile.** No Service is exposed; reach the pod directly with a
port-forward:

```bash
kubectl port-forward deploy/<fullname>-heap-profile 6060:6060
# in another shell:
curl -o heap.pb.gz localhost:6060/debug/pprof/heap
# or the rendered profile in a browser:
go tool pprof -http=:0 heap.pb.gz
```

**Security.** The listener is reachable in-cluster by pod IP only, and is never
published through a Service or Ingress. If your cluster enforces
NetworkPolicies, enable `heapProfiling.networkPolicy.enabled: true`; the chart
renders a policy that selects the canary, keeps the API `http` port open and
restricts the `pprof` port to `heapProfiling.networkPolicy.from` peers (with no
peers listed the port is denied; `kubectl port-forward` still works). Without
a policy, any in-cluster workload that can reach the pod IP can read the heap
profile, so treat the port as sensitive and prefer the NetworkPolicy on shared
clusters.

**Grafana k8s-monitoring (Alloy).** The chart adds the annotation-driven pprof
scrape keys used by the `feature-profiling` chart (verified against
grafana/k8s-monitoring-helm `k8s-monitoring-3.7.1`,
`charts/k8s-monitoring/charts/feature-profiling/templates/_pprof.tpl`):

| Annotation | Value |
|------------|-------|
| `profiles.grafana.com/memory.scrape` | `"true"` |
| `profiles.grafana.com/memory.port_name` | `pprof` |
| `profiles.grafana.com/memory.path` | `/debug/pprof/heap` |
| `resource.opentelemetry.io/service.name` | `heapProfiling.serviceName` (default `<fullname>-api`) |

The annotation prefix and actions are configurable in the monitoring chart
(`profiling.annotations.prefix`, `profiling.pprof.annotations.*`); if you
override them, mirror the changes here. The canary keeps the API `http` port
and Service selector labels, so the existing ServiceMonitor (port `http`, path
`/metrics`) scrapes it as an ordinary API pod, including the always-on
`/internal/metrics` Prometheus metrics.

**HPA / PDB.** The chart does not render HorizontalPodAutoscaler or
PodDisruptionBudget objects. If you add one externally that selects the shared
API labels, remember it will also match the canary pod: an average-CPU HPA
metric will include the canary's usage (sampling adds allocator CPU, so this can
skew scaling decisions; size targets for it or keep the canary short-lived),
and a PDB will count it toward
`minAvailable`/`maxUnavailable`. The canary is not added to any chart-managed
object beyond its own Deployment (and optional NetworkPolicy).

### Schema migrations as a pre-rollout Job

By default every application pod applies pending schema migrations when it
starts. For rolling deployments that is fragile: DDL is tied to pod lifecycle
and startup probes, and a migration that fails part-way keeps every new pod
from starting. Enable the migration Job instead:

```yaml
image:
  tag: "11.15.0"          # any control-layer >= 11.15 (has `dwctl migrate`)
postgresql:
  enabled: false           # the Job needs an external database
secrets:
  controlLayer:
    data:
      DATABASE_URL: postgres://...
migrations:
  job:
    enabled: true
```

The chart then renders a Job that runs `dwctl migrate` with the exact
application image, as an Argo CD `PreSync` hook and a Helm
`pre-install,pre-upgrade` hook, together with hook-phase copies of the config
and credentials it needs (a `PreSync` hook runs before the chart's ordinary
ConfigMap and Secret are updated). Both hook systems wait for the Job and
abort the rollout when it fails, leaving the previous ReplicaSets serving. The
Job repairs interrupted `CONCURRENTLY` index builds before applying migrations
and verifies them afterwards; every run is safe to repeat.

By default, Application and Fusillade pods get `DWCTL_MIGRATIONS__MODE=check`:
they never execute DDL and refuse to start on a database that is behind their
release, while accepting one that is ahead, so old replicas keep serving during
an additive migration. `migrations.startupMode: run` keeps in-process
migrations on the pods alongside the Job, for a deliberate transition only; the
key cannot be set through `env`.

The Job loads the application's primary Secret (chart-owned or
`existingSecret`) and `extraExistingSecrets` first, then its own hook-phase
Secret last so its keys win. When credentials are updated in the same sync as
the image (a rotated `DATABASE_URL` after a database refresh), pass them to the
Job explicitly so it does not read the previous values from a not-yet-updated
Secret:

```yaml
migrations:
  job:
    enabled: true
    secretData:
      DATABASE_URL: postgres://...   # rendered into the Job's hook-phase Secret
```

Requires an image with the `migrate` subcommand (control-layer ≥ 11.15).
`migrations.job.activeDeadlineSeconds`, `backoffLimit`, `resources` and
`ttlSecondsAfterFinished` bound the Job. Names are stable, so one Job exists at
a time; it is kept until the next sync replaces it when `ttlSecondsAfterFinished`
is unset, so a failure can be diagnosed from its logs. The Job cannot be used
with the in-chart PostgreSQL (`postgresql.enabled`), because the hook runs
before that StatefulSet exists.

### Fusillade Daemon Configuration

The fusillade daemon handles background batch processing tasks. By default, it runs within the control layer pods based on leader election. You can optionally deploy it as a separate deployment for better resource isolation and independent scaling.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fusillade.enabled` | Deploy fusillade as a separate deployment | `false` |
| `fusillade.replicaCount` | Number of fusillade replicas | `1` |
| `fusillade.mode` | Optional daemon mode for the standard fusillade deployment (`both`, `request_only`, `batch_only`); empty uses the application default | `""` |
| `fusillade.split.enabled` | Render separate request-only and batch-only daemon deployments | `false` |
| `fusillade.split.request.enabled` | Render the request-only daemon deployment | `true` |
| `fusillade.split.request.replicaCount` | Number of request daemon replicas | inherits `fusillade.replicaCount` |
| `fusillade.split.request.resources` | CPU/Memory requests/limits for request daemon pods | inherits `fusillade.resources` |
| `fusillade.split.request.env` | Additional environment variables for request daemon pods | merged after `env` and `fusillade.env` |
| `fusillade.split.request.database` | Database pool overrides for request daemon pods | merged over `fusillade.database` |
| `fusillade.split.batch.enabled` | Render the batch-only daemon deployment | `true` |
| `fusillade.split.batch.replicaCount` | Number of batch daemon replicas | inherits `fusillade.replicaCount` |
| `fusillade.split.batch.resources` | CPU/Memory requests/limits for batch daemon pods | inherits `fusillade.resources` |
| `fusillade.split.batch.env` | Additional environment variables for batch daemon pods | merged after `env` and `fusillade.env` |
| `fusillade.split.batch.database` | Database pool overrides for batch daemon pods | merged over `fusillade.database` |
| `fusillade.image.repository` | Override image repository | (uses main image) |
| `fusillade.image.tag` | Override image tag | (uses main image) |
| `fusillade.resources` | CPU/Memory resource requests/limits | `{}` |
| `fusillade.podAnnotations` | Annotations for fusillade pods | `{}` |
| `fusillade.podLabels` | Labels for fusillade pods | `{}` |
| `fusillade.nodeSelector` | Node selector for fusillade pods | `{}` |
| `fusillade.tolerations` | Tolerations for fusillade pods | `[]` |
| `fusillade.affinity` | Affinity rules for fusillade pods | `{}` |
| `fusillade.env` | Additional environment variables | `{}` |

When `fusillade.enabled: true`:
- The control layer pods will have `background_services.batch_daemon.enabled` set to `never`
- The fusillade pods will have `background_services.batch_daemon.enabled` set to `always`
- The standard fusillade deployment uses the application's default daemon mode unless `fusillade.mode` is set
- With `fusillade.split.enabled: true`, request pods use `mode=request_only` and batch pods use `mode=batch_only`

### Keystore Redis

Enabling the ZDR keystore deploys a single-instance Redis StatefulSet and
Service by default. The internal keystore can create and use a dedicated
StorageClass for its Redis PVC. On GKE, set `disk-encryption-kms-key` to
provision the backing Persistent Disk with a customer-managed Cloud KMS key:

```yaml
keystore:
  enabled: true
  persistence:
    managedStorageClass:
      enabled: true
      parameters:
        type: pd-balanced
        disk-encryption-kms-key: projects/PROJECT_ID/locations/REGION/keyRings/KEY_RING/cryptoKeys/KEY
```

Existing PVCs keep the StorageClass they were created with. Recreate or migrate
the keystore volume to move an existing install onto the managed StorageClass.

To use a separately managed Redis service, first create a Secret in the release
namespace containing the complete connection URL. The resulting Secret must
have this shape; supply its value through your secret-management workflow and
do not commit the populated manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: external-keystore
type: Opaque
data:
  redis-url: <base64-encoded-redis-connection-url>
```

Then enable external mode and reference the Secret:

```yaml
keystore:
  enabled: true
  external:
    enabled: true
    existingSecret: external-keystore
    existingSecretKey: redis-url
```

External mode does not render the internal Redis StatefulSet, Service, or
managed StorageClass. Both the control layer and Fusillade workloads read
`DWCTL_KEYSTORE__REDIS_URL` directly from the Secret; the connection URL is not
placed in ordinary Helm values or rendered manifests. Provision and validate
the external service and Secret before enabling this mode. The chart passes the
URL through unchanged, so the selected application image must support the
provider's Redis URL scheme, TLS configuration, and authentication method.

## Example Configurations

### With External Database

```yaml
# custom-values.yaml
replicaCount: 2

image:
  tag: "v1.2.3"

postgresql:
  enabled: false

secrets:
  controlLayer:
    create: true
    data:
      DATABASE_URL: "postgres://user:password@external-db.example.com:5432/controldb"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### With Prometheus Monitoring

```yaml
# monitoring-values.yaml
serviceMonitor:
  enabled: true
  interval: 15s
  labels:
    prometheus: kube-prometheus
```

### With Separate Fusillade Deployment

```yaml
# fusillade-values.yaml
replicaCount: 3

fusillade:
  enabled: true
  replicaCount: 2
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

### With Split Fusillade Daemons

```yaml
# split-fusillade-values.yaml
fusillade:
  enabled: true
  split:
    enabled: true
    request:
      replicaCount: 4
      resources:
        requests:
          cpu: 500m
          memory: 512Mi
    batch:
      replicaCount: 1
      resources:
        requests:
          cpu: 1000m
          memory: 1Gi
      database:
        fusillade_pool:
          max_connections: 80
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.
