# Helm chart justfile for control-layer

# Default recipe - show available commands
default:
    @just --list

# Lint the Helm chart
lint:
    @echo "🔍 Linting Helm chart..."
    helm lint .
    @echo "✅ Lint passed"

# Run all Helm tests (unit tests + template rendering)
test:
    @echo "🧪 Running Helm tests..."
    @echo ""
    @echo "→ Running unit tests..."
    @if [ -d "tests" ]; then \
        helm unittest .; \
    else \
        echo "  ⚠️  No tests directory found, skipping unit tests"; \
    fi
    @echo ""
    @echo "→ Testing template rendering with default values..."
    @helm template test-release . > /dev/null
    @echo "→ Testing with serviceMonitor enabled..."
    @helm template test-release . --set serviceMonitor.enabled=true > /dev/null
    @echo "→ Testing with external database..."
    @helm template test-release . \
        --set postgresql.enabled=false \
        --set secrets.controlLayer.data.DATABASE_URL="postgres://user:pass@host:5432/db" > /dev/null
    @echo ""
    @echo "✅ All tests passed"

# Full release workflow: lint, test, package, and publish
release version: lint test
    @echo ""
    @echo "📦 Packaging Helm chart version {{version}}..."
    helm package . --version {{version}}
    @echo ""
    @echo "🚀 Publishing chart version {{version}} to OCI registry..."
    helm push control-layer-{{version}}.tgz oci://ghcr.io/doublewordai/charts
    @echo ""
    @echo "✅ Chart published to ghcr.io/doublewordai/charts/control-layer:{{version}}"
    @echo ""
    @echo "📦 Installation command:"
    @echo "   helm install my-control-layer oci://ghcr.io/doublewordai/charts/control-layer --version {{version}}"
