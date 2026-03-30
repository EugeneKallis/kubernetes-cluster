#!/bin/bash
# Usage: ./setup-dockerhub-secret.sh <your-dockerhub-token>

TOKEN=$1

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <dockerhub-token>"
  exit 1
fi

for NS in development production; do
  echo "Creating dockerhub-creds secret in namespace: $NS"
  kubectl create secret docker-registry dockerhub-creds \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username=eugenekallis \
    --docker-password="$TOKEN" \
    --namespace="$NS" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Patching default service account in namespace: $NS"
  kubectl patch serviceaccount default \
    -n "$NS" \
    -p '{"imagePullSecrets": [{"name": "dockerhub-creds"}]}'
done

echo "Done."
