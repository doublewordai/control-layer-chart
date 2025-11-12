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

### Install the Chart

```bash
helm install my-control-layer ./control-layer-helm
```

### Install with Custom Values

```bash
helm install my-control-layer ./control-layer-helm -f custom-values.yaml
```

### Upgrade the Chart

```bash
helm upgrade my-control-layer ./control-layer-helm
```

### Uninstall the Chart

```bash
helm uninstall my-control-layer
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

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE.md](LICENSE.md) file for details.
