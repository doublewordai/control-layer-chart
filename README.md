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

### Fusillade Daemon Configuration

The fusillade daemon handles background batch processing tasks. By default, it runs within the control layer pods based on leader election. You can optionally deploy it as a separate deployment for better resource isolation and independent scaling.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fusillade.enabled` | Deploy fusillade as a separate deployment | `false` |
| `fusillade.replicaCount` | Number of fusillade replicas | `1` |
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

### Scouter Configuration

Scouter is a capacity reporting service that polls the control-layer admin/monitoring endpoints (e.g. `/admin/api/v1/models` and `/admin/api/v1/monitoring/pending-request-counts`) and exposes a `/report` endpoint.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scouter.enabled` | Deploy scouter as a separate deployment | `false` |
| `scouter.replicaCount` | Number of scouter replicas | `1` |
| `scouter.image.repository` | Scouter image repository | `ghcr.io/doublewordai/scouter` |
| `scouter.image.tag` | Scouter image tag | `latest` |
| `scouter.service.type` | Scouter service type | `LoadBalancer` |
| `scouter.service.port` | Scouter HTTP port | `4321` |
| `scouter.controlLayerBaseUrl` | Control-layer base URL scouter will call | (defaults to in-cluster service) |
| `secrets.controlLayer.data.SYSTEM_API_KEY` | Shared API key used by control-layer and scouter | `""` |
| `scouter.env` | Additional env vars | `{}` |

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

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.
