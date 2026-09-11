{{/*
Expand the name of the chart.
*/}}
{{- define "control-layer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "control-layer.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "control-layer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "control-layer.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: control-layer
{{- end }}

{{/*
Selector labels
*/}}
{{- define "control-layer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "control-layer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for postgres
*/}}
{{- define "control-layer.postgres.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
Selector labels for postgres
*/}}
{{- define "control-layer.postgres.selectorLabels" -}}
app.kubernetes.io/name: {{ include "control-layer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "control-layer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "control-layer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret consumed by control-layer and Fusillade workloads.
*/}}
{{- define "control-layer.secretName" -}}
{{- default (printf "%s-secret" (include "control-layer.fullname" .)) .Values.secrets.controlLayer.existingSecret -}}
{{- end }}

{{/*
Common labels for fusillade
*/}}
{{- define "control-layer.fusillade.labelsFor" -}}
helm.sh/chart: {{ include "control-layer.chart" .root }}
{{ include "control-layer.fusillade.selectorLabelsFor" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{- define "control-layer.fusillade.labels" -}}
{{ include "control-layer.fusillade.labelsFor" (dict "root" . "component" "fusillade") }}
{{- end }}

{{/*
Selector labels for fusillade
*/}}
{{- define "control-layer.fusillade.selectorLabelsFor" -}}
app.kubernetes.io/name: {{ include "control-layer.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "control-layer.fusillade.selectorLabels" -}}
{{ include "control-layer.fusillade.selectorLabelsFor" (dict "root" . "component" "fusillade") }}
{{- end }}

{{/*
Common labels for keystore (ZDR key custody Redis)
*/}}
{{- define "control-layer.keystore.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: keystore
{{- end }}

{{/*
Selector labels for keystore
*/}}
{{- define "control-layer.keystore.selectorLabels" -}}
app.kubernetes.io/name: {{ include "control-layer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: keystore
{{- end }}

{{/*
Name for the chart-managed keystore StorageClass.
*/}}
{{- define "control-layer.keystore.storageClassName" -}}
{{- default (printf "%s-keystore-cmek" (include "control-layer.fullname" .)) .Values.keystore.persistence.managedStorageClass.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
StorageClass selected by the keystore PVC. A managed class takes precedence over
the legacy storageClass string because the chart also creates that class.
*/}}
{{- define "control-layer.keystore.persistenceStorageClassName" -}}
{{- if .Values.keystore.persistence.managedStorageClass.enabled -}}
{{- include "control-layer.keystore.storageClassName" . -}}
{{- else -}}
{{- .Values.keystore.persistence.storageClass -}}
{{- end -}}
{{- end }}

{{/*
ZDR keystore env wiring, shared by the control-layer and fusillade Deployments so
the two cannot drift. The fusillade daemon is what encrypts flex bodies, so it
needs the keystore env just as much as the API pods do. Callers guard on
.Values.keystore.enabled and set indentation, e.g.:
  {{- if .Values.keystore.enabled }}
  {{- include "control-layer.keystoreEnv" . | nindent 12 }}
  {{- end }}
redis_url targets the in-cluster keystore Service by default. In external mode it
is sourced from an existing Secret so credentials never pass through ordinary
Helm values. current_wrap_key_id comes from values. The wrap key(s) are supplied
as secrets.controlLayer.data: DWCTL_KEYSTORE__WRAP_KEYS__<ID>.
default_ttl_seconds defaults in dwctl (7200s); set keystore.defaultTtlSeconds to
override it.
*/}}
{{- define "control-layer.keystoreEnv" -}}
{{- $external := .Values.keystore.external | default dict -}}
- name: DWCTL_KEYSTORE__REDIS_URL
{{- if $external.enabled }}
  valueFrom:
    secretKeyRef:
      name: {{ required "keystore.external.existingSecret is required when external keystore is enabled" $external.existingSecret | quote }}
      key: {{ required "keystore.external.existingSecretKey is required when external keystore is enabled" $external.existingSecretKey | quote }}
{{- else }}
  value: "redis://{{ include "control-layer.fullname" . }}-keystore:6379"
{{- end }}
- name: DWCTL_KEYSTORE__CURRENT_WRAP_KEY_ID
  value: {{ .Values.keystore.currentWrapKeyId | quote }}
{{- with .Values.keystore.defaultTtlSeconds }}
- name: DWCTL_KEYSTORE__DEFAULT_TTL_SECONDS
  value: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
Migration Job: a short stable hash of the image reference, so each release
gets its own Job/ConfigMap/Secret names (and hook replacement is per release).
*/}}
{{- define "control-layer.migrations.imageHash" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) | sha256sum | trunc 8 -}}
{{- end }}

{{- define "control-layer.migrations.jobName" -}}
{{- printf "%s-migrate-%s" (include "control-layer.fullname" . | trunc 46 | trimSuffix "-") (include "control-layer.migrations.imageHash" .) -}}
{{- end }}

{{- define "control-layer.migrations.configMapName" -}}
{{- printf "%s-migrate-config-%s" (include "control-layer.fullname" . | trunc 39 | trimSuffix "-") (include "control-layer.migrations.imageHash" .) -}}
{{- end }}

{{- define "control-layer.migrations.secretName" -}}
{{- printf "%s-migrate-secret-%s" (include "control-layer.fullname" . | trunc 39 | trimSuffix "-") (include "control-layer.migrations.imageHash" .) -}}
{{- end }}

{{/*
Labels for migration resources. Deliberately NOT the Deployment selector
labels plus component=control-layer, so Services and PDBs never match the
Job's pod.
*/}}
{{- define "control-layer.migrations.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: migrations
{{- end }}

{{/*
Credentials for the migration Job's hook-phase Secret, as YAML: the non-empty
entries of secrets.controlLayer.data (skipped entirely when the chart Secret
is not rendered, i.e. an existingSecret is in use) overlaid with the non-empty
entries of migrations.job.secretData.
*/}}
{{- define "control-layer.migrations.secretData" -}}
{{- $data := dict -}}
{{- if not .Values.secrets.controlLayer.existingSecret -}}
{{- range $key, $value := .Values.secrets.controlLayer.data -}}
{{- if $value -}}{{- $_ := set $data $key $value -}}{{- end -}}
{{- end -}}
{{- /* Same in-chart PostgreSQL URL secret.yaml generates when none is given. */ -}}
{{- if and (not (get $data "DATABASE_URL")) .Values.postgresql.enabled -}}
{{- $pg := .Values.secrets.postgres.data -}}
{{- $_ := set $data "DATABASE_URL" (printf "postgres://%s:%s@%s-postgres:5432/%s" $pg.POSTGRES_USER $pg.POSTGRES_PASSWORD (include "control-layer.fullname" .) $pg.POSTGRES_DB) -}}
{{- end -}}
{{- end -}}
{{- range $key, $value := .Values.migrations.job.secretData -}}
{{- if $value -}}{{- $_ := set $data $key $value -}}{{- end -}}
{{- end -}}
{{- toYaml $data -}}
{{- end }}

{{/*
"true" when the migration Job has any credentials to render into its own Secret.
*/}}
{{- define "control-layer.migrations.hasSecretData" -}}
{{- if include "control-layer.migrations.secretData" . | fromYaml -}}true{{- end -}}
{{- end }}

{{/*
Hook annotations for the migration resources. Argo CD and Helm each get
their own set: Argo runs PreSync hooks before the Sync phase and fails the
sync when the Job fails; Helm runs pre-install/pre-upgrade hooks before the
release manifests and aborts the upgrade when the Job fails.

BeforeHookCreation (and nothing else): the resources are replaced by the next
sync and otherwise kept, so a failed Job, its pod and its logs stay available
for diagnosis. Argo serialises operations per Application, so this never
deletes a Job that is still running.

Takes a dict: root (the chart context), weight (Helm hook weight), wave
(Argo sync wave). Config/Secret use a lower weight/wave than the Job so they
exist before its pod is scheduled.
*/}}
{{- define "control-layer.migrations.hookAnnotations" -}}
{{- $root := .root -}}
{{- if $root.Values.migrations.job.argocd.enabled -}}
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
argocd.argoproj.io/sync-wave: {{ .wave | toString | quote }}
{{- end }}
{{- if $root.Values.migrations.job.helmHooks.enabled }}
{{ if $root.Values.migrations.job.argocd.enabled }}{{ end -}}
helm.sh/hook: pre-install,pre-upgrade
helm.sh/hook-weight: {{ .weight | toString | quote }}
helm.sh/hook-delete-policy: before-hook-creation
{{- end }}
{{- end }}
