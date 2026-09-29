{{/*
Heap-profiling additions for the API pod template, as JSON: {annotations, env,
ports}. Rendered onto the API Deployment when heapProfiling.enabled.
*/}}
{{- define "control-layer.heapProfiling.options" -}}
{{- $root := .root -}}
{{- $fullname := include "control-layer.fullname" $root -}}
{{- /*
Pod annotations. Grafana k8s-monitoring (Alloy) feature-profiling discovers
pprof targets via annotations, whose keys are
"<prefix>/<type>.<action>" (prefix defaults to profiles.grafana.com, action
names default to scrape/port_name/path). The Pyroscope service_name is chosen
from the first of resource.opentelemetry.io/service.name,
app.kubernetes.io/instance, app.kubernetes.io/name, container name; we pin it
with the OpenTelemetry resource annotation so profiles are grouped under one
service_name for the API tier.
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
{{- dict "annotations" $podAnnotations "env" $profEnv "ports" $ports | toJson -}}
{{- end -}}
