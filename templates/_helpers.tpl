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
Common labels for chunk-relay (flex live-streaming Redis relay)
*/}}
{{- define "control-layer.chunkRelay.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: chunk-relay
{{- end }}

{{/*
Selector labels for chunk-relay
*/}}
{{- define "control-layer.chunkRelay.selectorLabels" -}}
app.kubernetes.io/name: {{ include "control-layer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: chunk-relay
{{- end }}

{{/*
Flex live-streaming chunk-relay env wiring, shared by the control-layer and
fusillade Deployments so the two cannot drift. The fusillade daemon makes the
actual upstream call and publishes chunks; the control-layer pods subscribe
and relay them to clients - both need the same redis_url. Callers guard on
.Values.chunkRelay.enabled and set indentation, e.g.:
  {{- if .Values.chunkRelay.enabled }}
  {{- include "control-layer.chunkRelayEnv" . | nindent 12 }}
  {{- end }}
redis_url targets the in-cluster chunk-relay Service by default. In external
mode it is sourced from an existing Secret so credentials never pass through
ordinary Helm values. Every other knob defaults in dwctl; set the matching
chunkRelay.* value only to override.
*/}}
{{- define "control-layer.chunkRelayEnv" -}}
{{- $external := .Values.chunkRelay.external | default dict -}}
- name: DWCTL_FLEX_LIVE_STREAMING__ENABLED
  value: "true"
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__REDIS_URL
{{- if $external.enabled }}
  valueFrom:
    secretKeyRef:
      name: {{ required "chunkRelay.external.existingSecret is required when external chunk relay is enabled" $external.existingSecret | quote }}
      key: {{ required "chunkRelay.external.existingSecretKey is required when external chunk relay is enabled" $external.existingSecretKey | quote }}
{{- else }}
  value: "redis://{{ include "control-layer.fullname" . }}-chunk-relay:6379"
{{- end }}
{{- with .Values.chunkRelay.streamTtlSeconds }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__STREAM_TTL_SECS
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.maxlen }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__MAXLEN
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.publishChannelCapacity }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__PUBLISH_CHANNEL_CAPACITY
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.readerPollIntervalMs }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__READER_POLL_INTERVAL_MS
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.publishWorkers }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__PUBLISH_WORKERS
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.readerWorkers }}
- name: DWCTL_FLEX_LIVE_STREAMING__CHUNK_RELAY__READER_WORKERS
  value: {{ . | quote }}
{{- end }}
{{- with .Values.chunkRelay.pollFallbackIntervalMs }}
- name: DWCTL_FLEX_LIVE_STREAMING__POLL_FALLBACK_INTERVAL_MS
  value: {{ . | quote }}
{{- end }}
{{- end }}
