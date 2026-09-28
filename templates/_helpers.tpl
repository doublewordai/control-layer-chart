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
Migration resource names. Stable (no per-image suffix) on purpose: both hook
systems replace a same-named hook before creating it (BeforeHookCreation /
before-hook-creation), so exactly one Job, ConfigMap and Secret exist at any
time, a failed Job stays until the next sync replaces it, and nothing
accumulates across releases. The image reference lives in the Job's pod spec.
*/}}
{{- define "control-layer.migrations.jobName" -}}
{{- printf "%s-migrate" (include "control-layer.fullname" . | trunc 55 | trimSuffix "-") -}}
{{- end }}

{{- define "control-layer.migrations.configMapName" -}}
{{- printf "%s-migrate-config" (include "control-layer.fullname" . | trunc 48 | trimSuffix "-") -}}
{{- end }}

{{- define "control-layer.migrations.secretName" -}}
{{- printf "%s-migrate-secret" (include "control-layer.fullname" . | trunc 48 | trimSuffix "-") -}}
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

BeforeHookCreation (and nothing else): the same-named resources are replaced
by the next sync and otherwise kept, so a failed Job, its pod and its logs
stay available for diagnosis (unless `ttlSecondsAfterFinished` collects them
first). Argo serialises operations per Application, so this never deletes a
Job that is still running.

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
{{/*
API pod template (the Deployment `spec.template` block), shared by the main
control-layer Deployment and the opt-in heap-profiling canary so the two pod
specs cannot drift. Call with a dict:
  root:    the chart context
  options: (optional) dict of canary-only additions
    extraPodLabels      additional pod labels, rendered after .Values.podLabels
    extraPodAnnotations additional pod annotations, rendered after .Values.podAnnotations
    extraPorts          list of {name, containerPort} ports appended after http
    extraEnv            map of extra container env, rendered last
    resources           resource block; falls back to .Values.resources when empty
Rendered output starts at "  template:" (two-space indent) so callers can
include it verbatim as the last child of their Deployment spec. Omitting
options renders byte-for-byte the same template as before this helper existed.
*/}}
{{- define "control-layer.api.podTemplate" -}}
{{- $root := .root -}}
{{- $opts := .options | default dict -}}
{{ "  " }}template:
    metadata:
      annotations:
        checksum/secret: {{ include (print $root.Template.BasePath "/secret.yaml") $root | sha256sum }}
        checksum/config: {{ include (print $root.Template.BasePath "/configmap.yaml") $root | sha256sum }}
        {{- if $root.Values.modelProvisioning.enabled }}
        checksum/model-provisioning: {{ include (print $root.Template.BasePath "/model-provisioning-configmap.yaml") $root | sha256sum }}
        {{- end }}
        {{- with $root.Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with $opts.extraPodAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "control-layer.labels" $root | nindent 8 }}
        {{- with $root.Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with $opts.extraPodLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- if $root.Values.rollout.enabled }}
      terminationGracePeriodSeconds: {{ $root.Values.rollout.terminationGracePeriodSeconds }}
      {{- end }}
      {{- with $root.Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "control-layer.serviceAccountName" $root }}
      {{- with $root.Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: control-layer
          {{- if $root.Values.rollout.enabled }}
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - sleep {{ $root.Values.rollout.endpointDrainDelaySeconds }}
          {{- end }}
          {{- with $root.Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ $root.Values.image.repository }}:{{ $root.Values.image.tag | default $root.Chart.AppVersion }}"
          imagePullPolicy: {{ $root.Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ $root.Values.service.port }}
              protocol: TCP
            {{- range $port := $opts.extraPorts }}
            - name: {{ $port.name }}
              containerPort: {{ $port.containerPort }}
              protocol: TCP
            {{- end }}
          envFrom:
            - secretRef:
                name: {{ include "control-layer.secretName" $root }}
            {{- range $root.Values.secrets.controlLayer.extraExistingSecrets }}
            - secretRef:
                name: {{ . | quote }}
            {{- end }}
          env:
            {{- if $root.Values.modelProvisioning.enabled }}
            - name: DWCTL_MODEL_PROVISIONING__ENABLED
              value: "true"
            - name: DWCTL_MODEL_PROVISIONING__DIRECTORY
              value: {{ $root.Values.modelProvisioning.mountPath | quote }}
            {{- end }}
            {{- if $root.Values.bootstrap.enabled }}
            - name: DASHBOARD_BOOTSTRAP_JS
              valueFrom:
                configMapKeyRef:
                  name: {{ include "control-layer.fullname" $root }}-bootstrap
                  key: bootstrap.js
            {{- end }}
            {{- if $root.Values.fusillade.enabled }}
            # Disable fusillade daemon on control-layer pods when running separately
            - name: DWCTL_BACKGROUND_SERVICES__BATCH_DAEMON__ENABLED
              value: "never"
            {{- end }}
            {{- if $root.Values.keystore.enabled }}
            {{- include "control-layer.keystoreEnv" $root | nindent 12 }}
            {{- end }}
            {{- /* The startup mode is reserved only while the Job owns migrations. */}}
            {{- $env := $root.Values.env }}
            {{- if $root.Values.migrations.job.enabled }}{{ $env = omit $env "DWCTL_MIGRATIONS__MODE" }}{{ end }}
            {{- range $key, $value := $env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- if $root.Values.migrations.job.enabled }}
            # The migration Job owns DDL; pods only verify schema compatibility.
            # Rendered last and excluded from `env` so nothing can override it.
            - name: DWCTL_MIGRATIONS__MODE
              value: {{ $root.Values.migrations.startupMode | quote }}
            {{- end }}
            {{- /* Heap-profiling and canary-only overrides, merged last. */}}
            {{- range $key, $value := $opts.extraEnv }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          {{- with $root.Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $root.Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $root.Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- $resources := $opts.resources | default $root.Values.resources }}
          {{- with $resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          volumeMounts:
            - name: config
              mountPath: /app/config.yaml
              subPath: control-layer-config.yaml
              readOnly: true
            {{- if $root.Values.modelProvisioning.enabled }}
            - name: model-provisioning
              mountPath: {{ $root.Values.modelProvisioning.mountPath }}
              readOnly: true
            {{- end }}
            {{- if $root.Values.emailTemplates.enabled }}
            - name: email-templates
              mountPath: {{ $root.Values.emailTemplates.mountPath }}
              readOnly: true
            {{- end }}
            {{- with $root.Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      volumes:
        - name: config
          configMap:
            name: {{ include "control-layer.fullname" $root }}-config
        {{- if $root.Values.modelProvisioning.enabled }}
        - name: model-provisioning
          configMap:
            name: {{ include "control-layer.fullname" $root }}-model-provisioning
        {{- end }}
        {{- if $root.Values.emailTemplates.enabled }}
        - name: email-templates
          configMap:
            name: {{ include "control-layer.fullname" $root }}-email-templates
        {{- end }}
        {{- with $root.Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $root.Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $root.Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}

{{- end }}
