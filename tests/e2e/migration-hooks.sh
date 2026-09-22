#!/usr/bin/env bash
# End-to-end check of the migration Job's ordering and failure handling on a
# real cluster, using Helm's hook engine (the Argo PreSync annotations sit on
# the same resources; Argo applies the same "hook completes before the Sync
# phase" rule).
#
# What it proves:
#   1. install: the Job runs and completes before any application pod exists,
#      applying the main, fusillade (schema mode) and underway migrations, and
#      the pods start in DWCTL_MIGRATIONS__MODE=check on the migrated DB.
#      (outlet is skipped: request logging is off, as in staging.)
#   2. failing upgrade: with unreachable hook credentials the Job fails, the
#      upgrade fails, and the previously running pods are untouched.
#   3. repair: a correct upgrade runs the Job again and rolls the pods.
#
# Requirements: kubectl pointed at a disposable cluster, helm, an image with
# `dwctl migrate` (control-layer >= 11.15) pullable by the cluster.
#
#   ./tests/e2e/migration-hooks.sh [image-tag]
set -euo pipefail
cd "$(dirname "$0")/../.."

TAG="${1:-11.16.0}"
NS="${NS:-migtest}"
REL="cl"
DB_URL="postgres://clay:clay@pg.$NS.svc:5432/clay"

log() { printf '\n== %s\n' "$*"; }
plain() { sed 's/\x1b\[[0-9;]*m//g'; }  # dwctl logs are coloured
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

log "namespace and a stand-in external Postgres"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" apply -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: pg }
spec:
  replicas: 1
  selector: { matchLabels: { app: pg } }
  template:
    metadata: { labels: { app: pg } }
    spec:
      containers:
        - name: pg
          image: postgres:17
          env:
            - { name: POSTGRES_USER, value: clay }
            - { name: POSTGRES_PASSWORD, value: clay }
            - { name: POSTGRES_DB, value: clay }
          ports: [{ containerPort: 5432 }]
          readinessProbe: { exec: { command: [pg_isready, -U, clay] }, periodSeconds: 2 }
---
apiVersion: v1
kind: Service
metadata: { name: pg }
spec:
  selector: { app: pg }
  ports: [{ port: 5432 }]
EOF
kubectl -n "$NS" rollout status deploy/pg --timeout=180s >/dev/null

values() { # $1 = DATABASE_URL for the hook secret
  cat <<EOF
image: { tag: "$TAG" }
postgresql: { enabled: false }
replicaCount: 1
secrets:
  controlLayer:
    data:
      DATABASE_URL: "$DB_URL"
      SYSTEM_API_KEY: "sk-e2e"
env:
  DWCTL_SECRET_KEY: "e2e-secret-key-e2e-secret-key-e2e"
  DWCTL_ENABLE_REQUEST_LOGGING: "false"
  RUST_LOG: info
migrations:
  job:
    enabled: true
    activeDeadlineSeconds: 300
    backoffLimit: 0
    secretData:
      DATABASE_URL: "$1"
EOF
}

log "1. install: Job must complete before any application pod exists"
helm uninstall "$REL" -n "$NS" >/dev/null 2>&1 || true
( sleep 2; while ! kubectl -n "$NS" get job "$REL-control-layer-migrate" >/dev/null 2>&1; do sleep 1; done
  pods=$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=control-layer -o name | wc -l)
  echo "  app pods present while the Job exists and Deployments are not yet applied: $pods" ) &
helm install "$REL" . -n "$NS" -f <(values "$DB_URL") --wait --timeout 10m >/dev/null
wait
kubectl -n "$NS" get job "$REL-control-layer-migrate" -o jsonpath='{.status.succeeded}' | grep -q 1 || fail "migration Job did not succeed"
job_done=$(kubectl -n "$NS" get job "$REL-control-layer-migrate" -o jsonpath='{.status.completionTime}')
pod_start=$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=control-layer -o jsonpath='{.items[0].metadata.creationTimestamp}')
[[ "$job_done" < "$pod_start" || "$job_done" == "$pod_start" ]] || fail "application pod ($pod_start) created before the Job finished ($job_done)"
echo "  Job completed $job_done; first app pod created $pod_start"
joblog=$(kubectl -n "$NS" logs "job/$REL-control-layer-migrate" | plain)
grep -q "dwctl migrate: all targets complete" <<<"$joblog" || fail "Job log lacks completion line"
for target in main fusillade; do
  grep -q "migration target complete.*target=\"$target\"" <<<"$joblog" || fail "Job did not report target $target complete"
done
grep -q 'migrations applied target="underway"' <<<"$joblog" || fail "Job did not apply underway migrations"
schemas=$(kubectl -n "$NS" exec deploy/pg -- psql -U clay -d clay -Atc \
  "select string_agg(n, ',' order by n) from (select nspname n from pg_namespace where nspname in ('public','fusillade','underway')) s")
[ "$schemas" = "fusillade,public,underway" ] || fail "expected schemas public, fusillade, underway; got: $schemas"
counts=$(kubectl -n "$NS" exec deploy/pg -- psql -U clay -d clay -Atc \
  "select (select count(*) from public._sqlx_migrations)||'/'||(select count(*) from fusillade._sqlx_migrations)||'/'||(select count(*) from underway._sqlx_migrations)")
echo "  migrations recorded (main/fusillade/underway): $counts"
kubectl -n "$NS" get deploy "$REL-control-layer" -o jsonpath='{.spec.template.spec.containers[0].env}' | grep -q '"name":"DWCTL_MIGRATIONS__MODE","value":"check"' || fail "pods not in check mode"
podlog=$(kubectl -n "$NS" logs deploy/"$REL-control-layer" | plain)
for target in main fusillade underway; do
  grep -q "schema compatible target=\"$target\"" <<<"$podlog" || fail "pod did not verify target $target"
done
echo "  PASS install ordering, check mode, compatibility check"
old_pod=$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=control-layer -o jsonpath='{.items[0].metadata.name}')

log "2. failing upgrade: bad hook credentials must fail the Job and leave $old_pod running"
if helm upgrade "$REL" . -n "$NS" -f <(values "postgres://clay:clay@nowhere.invalid:5432/clay") --wait --timeout 3m >/dev/null 2>&1; then
  fail "upgrade succeeded with an unreachable database"
fi
kubectl -n "$NS" get job "$REL-control-layer-migrate" -o jsonpath='{.status.failed}' | grep -q 1 || fail "Job did not record a failure"
kubectl -n "$NS" get pod "$old_pod" -o jsonpath='{.status.phase}' | grep -q Running || fail "old pod is not running after the failed upgrade"
[ "$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=control-layer -o name | wc -l)" = 1 ] || fail "extra application pods appeared during the failed upgrade"
kubectl -n "$NS" logs "job/$REL-control-layer-migrate" | plain | grep -q "dwctl migrate failed" || fail "failed Job log lacks the failure line"
echo "  PASS failed Job blocked the rollout; old pod still serving; failure diagnosable from the Job's logs"

log "3. repair: a correct upgrade reruns the Job and rolls the pods"
helm upgrade "$REL" . -n "$NS" -f <(values "$DB_URL") --set env.E2E_ROLL=1 --wait --timeout 10m >/dev/null
kubectl -n "$NS" get job "$REL-control-layer-migrate" -o jsonpath='{.status.succeeded}' | grep -q 1 || fail "repair Job did not succeed"
new_pod=$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=control-layer -o jsonpath='{.items[0].metadata.name}')
[ "$new_pod" != "$old_pod" ] || fail "pods did not roll after the repaired upgrade"
echo "  PASS repaired upgrade: Job succeeded, pods rolled ($old_pod -> $new_pod)"

log "all checks passed"
