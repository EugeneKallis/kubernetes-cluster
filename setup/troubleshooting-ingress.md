# Troubleshooting: Ingress URLs Unreachable (Stale ARP)

## Symptoms

- `argocd.k3s.lan`, `servertool.k3s.lan`, etc. return "Connection refused" or time out
- The cluster nodes are healthy and pods are running
- DNS resolves correctly to `192.168.1.254`

## Why This Happens

MetalLB uses Layer 2 (ARP) to advertise the floating VIP `192.168.1.254`. When your Proxmox VMs restart, they can come back with **new MAC addresses**. Your Mac (and other devices) still have the **old MAC** cached in their ARP table, so traffic gets sent to a MAC that no longer exists on the network.

## Steps to Fix

### 1. Confirm the cluster is healthy

```bash
kubectl get nodes -o wide
kubectl get pods -n traefik
kubectl get pods -n metallb-system
```

All nodes should be `Ready`, all Traefik and MetalLB pods `Running`.

### 2. Verify apps work via NodePort (bypasses the VIP)

```bash
# Get the NodePort for the Traefik service
kubectl get svc -n traefik

# Test directly against a node IP using the NodePort (e.g. 30661)
curl -H "Host: argocd.k3s.lan" http://192.168.1.141:30661
```

If this returns a `200`, the problem is ARP — not Traefik or your apps.

### 3. Check for a stale ARP entry

```bash
# What MAC does your Mac think the VIP has?
arp -an | grep 192.168.1.254

# What MACs do the actual nodes have?
arp -an | grep 192.168.1.14
```

If the VIP MAC doesn't match any node MAC, you have a stale ARP entry.

### 4. Restart the MetalLB speaker to send fresh ARP broadcasts

```bash
# Find which node is currently announcing the VIP
kubectl get events -n traefik --sort-by='.lastTimestamp' | grep nodeAssigned

# List speaker pods and find the one on the announcing node
kubectl get pods -n metallb-system -o wide

# Delete that speaker pod (the DaemonSet will recreate it)
kubectl delete pod -n metallb-system <speaker-pod-name>
```

### 5. Verify the fix

```bash
# Wait ~10 seconds, then check the ARP entry updated
arp -an | grep 192.168.1.254

# Test your ingress URLs
curl http://argocd.k3s.lan
curl http://servertool.k3s.lan
curl http://mission-control.k3s.lan
```

The VIP MAC should now match one of your node MACs, and all URLs should return `200`.

## Prevention

Pin MAC addresses on your Proxmox VMs so they don't change across reboots. In the Proxmox UI: **VM → Hardware → Network Device → Edit → MAC address**. Or edit `/etc/pve/qemu-server/<vmid>.conf` directly:

```
net0: virtio=BC:24:11:58:B4:61,bridge=vmbr0
```
