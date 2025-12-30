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
Common labels for fusillade
*/}}
{{- define "control-layer.fusillade.labels" -}}
helm.sh/chart: {{ include "control-layer.chart" . }}
{{ include "control-layer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: fusillade
{{- end }}

{{/*
Selector labels for fusillade
*/}}
{{- define "control-layer.fusillade.selectorLabels" -}}
app.kubernetes.io/name: {{ include "control-layer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: fusillade
{{- end }}
