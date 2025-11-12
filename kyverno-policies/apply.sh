
---

## `apply.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Applying Kyverno policies from $ROOT_DIR/policies..."

kubectl apply -f "$ROOT_DIR/policies/01-deny-delete-namespaces.yaml"
kubectl apply -f "$ROOT_DIR/policies/02-deny-loadbalancer-services.yaml"
kubectl apply -f "$ROOT_DIR/policies/03-restrict-replica-count.yaml"
kubectl apply -f "$ROOT_DIR/policies/04-pv-capacity-limit.yaml"
kubectl apply -f "$ROOT_DIR/policies/05-pvc-capacity-limit.yaml"
kubectl apply -f "$ROOT_DIR/policies/06-connect-apps-deployment-labels.yaml"
kubectl apply -f "$ROOT_DIR/policies/07-connect-apps-pod-labels.yaml"
kubectl apply -f "$ROOT_DIR/policies/08-connect-apps-deployment-controls.yaml"
kubectl apply -f "$ROOT_DIR/policies/09-enforce-connect-apps-image-registry.yaml"
kubectl apply -f "$ROOT_DIR/policies/10-require-requests-limits-connect-apps.yaml"
kubectl apply -f "$ROOT_DIR/policies/11-require-versioned-image-tags.yaml"
kubectl apply -f "$ROOT_DIR/policies/12-generate-namespace-resourcequota.yaml"
kubectl apply -f "$ROOT_DIR/policies/13-disallow-stringdata-secrets.yaml"
kubectl apply -f "$ROOT_DIR/policies/14-deny-plaintext-envvars.yaml"
kubectl apply -f "$ROOT_DIR/policies/15-ingress-require-tls-and-approved-secret.yaml"

echo "All policies applied."
