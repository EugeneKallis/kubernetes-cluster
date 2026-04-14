# AGENTS.md

This file provides guidance for agentic coding agents operating in this repository.

## Repository Overview

This is a **GitOps-managed Kubernetes cluster configuration**. ArgoCD watches this repo (branch: `main`) and automatically syncs changes to the cluster. The repository contains:

- **Helm charts**: Umbrella charts with sub-charts for backend, frontend, agent, infrastructure services
- **ArgoCD Application definitions**: In `apps/` directory
- **Setup manifests**: One-time cluster setup resources in `setup/`

## Build/Lint/Test Commands

### Helm Validation

```bash
# Lint a Helm chart
helm lint charts/<chart-name>

# Template a chart to validate syntax (dry-run)
helm template <release-name> charts/<chart-name>

# Template with values files
helm template <release-name> charts/servertool-python -f charts/servertool-python/values-dev.yaml

# Template umbrella chart with all dependencies
helm template <release-name> charts/servertool-python \
  -f charts/servertool-python/values-dev.yaml \
  -f charts/servertool-python/values-prod.yaml
```

### Kubernetes Manifest Validation

```bash
# Dry-run apply (requires cluster connection)
kubectl apply -f <file.yaml> --dry-run=server

# Dry-run client-side only
kubectl apply -f <file.yaml> --dry-run=client

# Validate YAML syntax
kubectl create --dry-run=client -f <file.yaml>

# Format/check YAML with kustomize
kustomize build <directory>
```

### ArgoCD Validation

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd

# Watch ArgoCD sync progress
kubectl get applications -n argocd -w

# Describe specific application for details
kubectl describe application <name> -n argocd
```

### Pre-commit Hooks

If pre-commit is configured:

```bash
# Install pre-commit hooks
pip install pre-commit  # or brew install pre-commit
pre-commit install

# Run all hooks manually
pre-commit run --all-files

# Run specific hook
pre-commit run <hook-id> --all-files
```

### Git Commands

```bash
# View staged changes
git diff --staged

# View unstaged changes
git diff

# Check git status
git status

# View commit history
git log --oneline -20
```

## Code Style Guidelines

### YAML Formatting

- Use **2-space indentation** (not tabs)
- Use `|` for multi-line strings where appropriate
- Use `>` for long single-line strings that wrap
- Remove trailing whitespace
- Use kebab-case for resource names: `my-resource-name`
- Use camelCase for metadata fields: `app.kubernetes.io/name`

### Kubernetes Manifest Conventions

- Always specify `apiVersion`, `kind`, `metadata.name`
- Include `namespace` in metadata for namespaced resources
- Use labels consistently:
  ```yaml
  labels:
    app.kubernetes.io/name: backend
    app.kubernetes.io/part-of: servertool
    app.kubernetes.io/environment: dev
  ```
- Use `spec.selector.matchLabels` that match `spec.template.metadata.labels`
- Always set `imagePullPolicy: Always` for dev environments

### Helm Chart Conventions

- Chart names use kebab-case: `my-chart`
- Template files use `{{ .Release.Name }}-<component>` for resource names
- Use `{{ .Values.xxx | default "default-value" | quote }}` for optional values
- Indent template directives consistently with surrounding YAML
- Use `{{- ... }}` to control whitespace when needed
- Environment-specific values go in `values-<env>.yaml` files at chart root

**Example environment values structure:**
```yaml
global:
  environment: "Development"
  image:
    tag: "dev-<short-sha>"
  ollamaHost: "http://192.168.1.203:11434"
  redisUrl: "redis://redis:6379/0"

backend:
  replicaCount: 2
  database:
    host: "192.168.1.150"
    port: "5432"
```

### ArgoCD Application Conventions

- Applications live in `apps/` directory
- One file per Application: `<app-name>-(dev|prod).yaml`
- Use `path: charts/<chart-name>` for Helm-based apps
- Set `syncPolicy.automated.prune: true` and `syncPolicy.automated.selfHeal: true`
- Always include `syncOptions: [CreateNamespace=true]` for namespace-scoped apps

**Standard ArgoCD Application structure:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app>-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/EugeneKallis/kubernetes-cluster.git
    targetRevision: HEAD
    path: charts/<chart-name>
    helm:
      valueFiles:
        - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Git Commit Message Conventions

Follow conventional commits format:

```
<type>: <short description>

[optional body]
```

**Types:**
- `feat:` — New feature or significant addition
- `fix:` — Bug fix
- `chore:` — Routine deployment, dependency updates
- `refactor:` — Code refactoring without behavior change
- `docs:` — Documentation changes

**Examples:**
```
feat: add scraper component to servertool umbrella chart
fix: update database secret references in deployment and values files
chore: deploy dev dev-04.14.02-52.5b6e21b9
refactor: extract common labels into helper templates
```

### Image Tag Conventions

- **Dev format**: `dev-<short-sha>` (e.g., `dev-d77af4a4`)
- **Prod format**: `<short-sha>` (e.g., `03c93351`)
- **Registry**: `eugenekallis/servertoolpython-{backend,frontend,agent}`

To update image tag, edit `global.image.tag` in the appropriate `values-*.yaml`.

### Resource Naming

- Use consistent prefixes/suffixes: `{{ .Release.Name }}-backend`
- Secrets: Use `.secret.yaml` extension for secret templates
- Examples: Use `.secret.example.yaml` extension for example files
- Ingress/HTTPRoute: Name should reflect the host or service

### Environment-Specific Configuration

- Development values: `values-dev.yaml`
- Production values: `values-prod.yaml`
- Never put production credentials in dev values files
- Use Kubernetes Secrets for sensitive data (not in values files)
- Example secret files should be clearly named: `<name>.secret.example.yaml`

### File Organization

```
charts/
  <umbrella-chart>/
    Chart.yaml              # Umbrella chart definition
    values.yaml             # Default values
    values-dev.yaml         # Dev overrides
    values-prod.yaml        # Prod overrides
    <subchart>/
      Chart.yaml
      values.yaml
      templates/
        deployment.yaml
        service.yaml
        ingress.yaml
apps/
  <app>-dev.yaml
  <app>-prod.yaml
setup/
  01-namespaces.yaml
  02-metallb.yaml
  ...
root.yaml                  # App-of-apps
```

## Important Notes

- **This repo auto-deploys to production** when merged to `main`. ArgoCD has `selfHeal: true`.
- Setup manifests in `setup/` are NOT managed by ArgoCD — apply them manually.
- Always run `helm lint` and `helm template` before committing chart changes.
- Verify ArgoCD sync status after pushing changes: `kubectl get applications -n argocd`
