# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GitOps-managed Kubernetes cluster configuration. ArgoCD watches this repo (branch: `main`) and automatically syncs changes to the cluster. Pushing to `main` triggers real deployments.

- **Root app**: `root.yaml` — ArgoCD app-of-apps that manages everything in `apps/`
- **Applications**: `apps/servertool-dev.yaml` and `apps/servertool-prod.yaml`
- **Helm chart**: `charts/servertool-python/` — umbrella chart with 4 sub-charts

## Deploying

Deployments happen automatically when changes are merged to `main`. ArgoCD is configured with `automated.prune: true` and `selfHeal: true`.

To apply changes to the cluster manually (for setup resources not managed by ArgoCD):
```bash
kubectl apply -f <file>
```

To check ArgoCD sync status:
```bash
kubectl get applications -n argocd
```

ArgoCD UI is at `http://argocd.k3s.lan` (IP: `192.168.1.254`).

## Helm Chart Structure

`charts/servertool-python/` is an umbrella chart with four local sub-charts:
- `backend/` — Python API, port 8080, needs `DATABASE_URL`, `REDIS_URL`, `OLLAMA_HOST`
- `frontend/` — Next.js app, port 3000, needs `NEXT_PUBLIC_API_URL`
- `agent/` — Python automation agent, runs privileged, mounts Docker socket and host `/mnt`
- `infrastructure/` — PostgreSQL 15 and Redis 7, both pinned to `k3s-master` node

Environment-specific overrides live in `values-dev.yaml` and `values-prod.yaml` at the chart root. These override image tags, replica counts, and hostnames.

### Image Tags

- Dev image tag format: `dev-<short-sha>` (e.g., `dev-d77af4a4`)
- Prod image tag format: `<short-sha>` (e.g., `03c93351`)
- Image registry: `eugenekallis/servertoolpython-{backend,frontend,agent}`

To update the image tag for a deployment, edit the `global.image.tag` field in the appropriate values file.

## Cluster Infrastructure

Set up once via `setup/` manifests (not managed by ArgoCD):
- **MetalLB**: Floating IP pool at `192.168.1.254`
- **Traefik**: Gateway controller (DaemonSet), Gateway API enabled
- **ArgoCD**: Installed with `--server-side` for large CRDs

Initial cluster setup order: namespaces → MetalLB → Traefik → ArgoCD → Gateway/HTTPRoute → `root.yaml`

See `setup/README.md` for full install commands.

## Networking

Domain routing uses local DNS (AdGuard Home or `/etc/hosts`):
- `argocd.k3s.lan` → ArgoCD UI
- `dev.servertool.k3s.lan` → development frontend
- `servertool.k3s.lan` → production frontend

All map to `192.168.1.254`. Routing is handled by Traefik via Gateway API `HTTPRoute` resources.

## Ollama

Both environments use an external Ollama instance at `http://192.168.1.125:11434`. This is configured via `global.ollamaHost` in the values files and injected as `OLLAMA_HOST` into the backend and agent deployments.
