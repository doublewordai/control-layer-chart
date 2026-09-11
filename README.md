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
| `replicaCount` | Number of replicas (omitted from the Deployment when `autoscaling.enabled`) | `1` |
| `autoscaling.enabled` | Render a HorizontalPodAutoscaler for the control-layer deployment | `false` |
| `autoscaling.minReplicas` | HPA minimum replicas | `1` |
| `autoscaling.maxReplicas` | HPA maximum replicas | `3` |
| `autoscaling.metrics` | Raw `autoscaling/v2` metrics list, rendered verbatim | `[]` |
| `autoscaling.behavior` | Raw `autoscaling/v2` behavior block, rendered verbatim | `{}` |
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

### Fusillade Daemon Configuration

The fusillade daemon handles background batch processing tasks. By default, it runs within the control layer pods based on leader election. You can optionally deploy it as a separate deployment for better resource isolation and independent scaling.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fusillade.enabled` | Deploy fusillade as a separate deployment | `false` |
| `fusillade.replicaCount` | Number of fusillade replicas (omitted from a Deployment whose effective autoscaling is enabled) | `1` |
| `fusillade.autoscaling` | HPA defaults for the fusillade daemon and both split roles (`enabled`, `minReplicas`, `maxReplicas`, `metrics`, `behavior`) | `enabled: false` |
| `fusillade.mode` | Optional daemon mode for the standard fusillade deployment (`both`, `request_only`, `batch_only`); empty uses the application default | `""` |
| `fusillade.split.enabled` | Render separate request-only and batch-only daemon deployments | `false` |
| `fusillade.split.request.enabled` | Render the request-only daemon deployment | `true` |
| `fusillade.split.request.replicaCount` | Number of request daemon replicas | inherits `fusillade.replicaCount` |
| `fusillade.split.request.autoscaling` | HPA override for the request daemon | merged over `fusillade.autoscaling` |
| `fusillade.split.request.resources` | CPU/Memory requests/limits for request daemon pods | inherits `fusillade.resources` |
| `fusillade.split.request.env` | Additional environment variables for request daemon pods | merged after `env` and `fusillade.env` |
| `fusillade.split.request.database` | Database pool overrides for request daemon pods | merged over `fusillade.database` |
| `fusillade.split.batch.enabled` | Render the batch-only daemon deployment | `true` |
| `fusillade.split.batch.replicaCount` | Number of batch daemon replicas | inherits `fusillade.replicaCount` |
| `fusillade.split.batch.autoscaling` | HPA override for the batch daemon | merged over `fusillade.autoscaling` |
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
