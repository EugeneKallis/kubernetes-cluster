# Kubernetes Cluster Setup Guide

This guide will help you set up **MetalLB**, **Gateway API**, **Traefik**, and **ArgoCD** in your 3-node Kubernetes cluster.

## 1. Prerequisites: Gateway API CRDs

The **Gateway API** is the modern standard for routing in Kubernetes. Install the CRDs first:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

## 2. Create Namespaces

```bash
kubectl apply -f setup/01-namespaces.yaml
```

- `traefik`: For our Gateway controller.
- `argocd`: For our CI/CD tool.
- `metallb-system`: For our Load Balancer (created automatically if using the manifest).

## 3. Install MetalLB (Floating IP)

MetalLB provides a "Floating IP" for your cluster.

1. Install MetalLB:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
   ```
2. Wait for pods to be ready:
   ```bash
   kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s
   ```
3. Apply the IP pool configuration (matches your `192.168.1.254` expectation):
   ```bash
   kubectl apply -f setup/metallb-config.yaml
   ```

## 4. Install Traefik

Traefik acts as our **Gateway Controller**. We configure it as a `DaemonSet` with `type: LoadBalancer`.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik \
  -f setup/traefik-values.yaml
```

## 5. Install ArgoCD

Install ArgoCD and ensure the CRDs are applied correctly (using `--server-side` to avoid size limits).

```bash
# Install core manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# IMPORTANT: Fix missing/large CRDs
kubectl apply --server-side -k https://github.com/argoproj/argo-cd/manifests/crds?ref=stable
```

### 5.1 Disable HTTP to HTTPS redirect

```bash
kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

### 5.2 Get Initial Admin Password

To log in for the first time, use the username `admin` and the password retrieved with this command:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

> **Note:** It is recommended to change this password after your first login!

### 5.3 Fix `copyutil` Init Container Bug

The upstream ArgoCD manifests use `ln -s` in the `copyutil` init container, which fails if the symlink already exists (e.g., after a container restart). This causes a `CrashLoopBackOff`. Apply this patch to use `ln -sf` instead:

```bash
kubectl patch deployment argocd-repo-server -n argocd --type='json' --patch-file setup/argocd-repo-server-patch.yaml
```

> **Note:** This patch must be re-applied after upgrading ArgoCD manifests.

## 6. Expose ArgoCD via Gateway API

```bash
kubectl apply -f setup/05-traefik-gateway.yaml
kubectl apply -f setup/04-argocd-httproute.yaml
```

## 7. Accessing the Cluster

Since you are using **AdGuard Home** (or a local hosts file), map the domain to the floating IP:

- **Domain**: `argocd.k3s.lan`
- **IP**: `192.168.1.254`

Visit at: [http://argocd.k3s.lan](http://argocd.k3s.lan)

## 8. Connect your Root Application

Finally, apply the `root.yaml` file to start the GitOps sync.

```bash
kubectl apply -f root.yaml
```
