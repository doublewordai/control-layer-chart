{{/*
Heap-profiling additions for an API pod template, as JSON: {labels,
annotations, env, ports}. Used by the canary Deployment and, with
heapProfiling.allApiPods, by the main API Deployment. `diagnostic` (bool) adds
the canary's diagnostic label.
*/}}
{{- define "control-layer.heapProfiling.options" -}}
{{- $root := .root -}}
{{- $fullname := include "control-layer.fullname" $root -}}
{{- /*
Pod labels: the diagnostic label plus any profile-specific labels. The base
labels (including app.kubernetes.io/component) are added by the shared pod
template, so the API Service and by extension the existing ServiceMonitor keep
routing traffic and scrapes to this pod.
*/ -}}
{{- $podLabels := dict -}}
{{- range $k, $v := $root.Values.heapProfiling.podLabels }}{{ $_ := set $podLabels $k $v }}{{ end -}}
{{- /* Set last: the selector depends on it, so podLabels cannot override it. */ -}}
{{- if .diagnostic }}{{- $_ := set $podLabels "control-layer.doubleword.ai/diagnostic" "heap-profile" -}}{{- end -}}
{{- /*
Pod annotations. Grafana k8s-monitoring (Alloy) feature-profiling discovers
pprof targets via annotations, whose keys are
"<prefix>/<type>.<action>" (prefix defaults to profiles.grafana.com, action
names default to scrape/port_name/path). The Pyroscope service_name is chosen
from the first of resource.opentelemetry.io/service.name,
app.kubernetes.io/instance, app.kubernetes.io/name, container name; we pin it
with the OpenTelemetry resource annotation so the canary shows up as a distinct
service rather than blending into the API instance.
*/ -}}
{{- $podAnnotations := dict -}}
{{- if $root.Values.heapProfiling.scrapeAnnotations -}}
{{- $_ := set $podAnnotations "profiles.grafana.com/memory.scrape" "true" -}}
{{- $_ := set $podAnnotations "profiles.grafana.com/memory.port_name" "pprof" -}}
{{- $_ := set $podAnnotations "profiles.grafana.com/memory.path" "/debug/pprof/heap" -}}
{{- $_ := set $podAnnotations "resource.opentelemetry.io/service.name" (default (printf "%s-api" $fullname) $root.Values.heapProfiling.serviceName) -}}
{{- end -}}
{{- range $k, $v := $root.Values.heapProfiling.podAnnotations }}{{ $_ := set $podAnnotations $k $v }}{{ end -}}
{{- /*
jemalloc sampling only turns on when _RJEM_MALLOC_CONF is present at process
start. DWCTL_HEAP_PROFILING__ENABLED starts the separate pprof listener; the
bind address keeps it off the API Service (which only publishes the http port).
heapProfiling.env is merged last so operators can override or extend this set.
*/ -}}
{{- $profEnv := dict
      "_RJEM_MALLOC_CONF" (printf "prof:true,prof_active:true,lg_prof_sample:%v" $root.Values.heapProfiling.lgProfSample)
      "DWCTL_HEAP_PROFILING__ENABLED" "true"
      "DWCTL_HEAP_PROFILING__BIND_ADDRESS" (printf "0.0.0.0:%v" $root.Values.heapProfiling.port) -}}
{{- range $k, $v := $root.Values.heapProfiling.env }}{{ $_ := set $profEnv $k $v }}{{ end -}}
{{- $ports := list (dict "name" "pprof" "containerPort" ($root.Values.heapProfiling.port | int)) -}}
{{- dict "labels" $podLabels "annotations" $podAnnotations "env" $profEnv "ports" $ports | toJson -}}
{{- end -}}
