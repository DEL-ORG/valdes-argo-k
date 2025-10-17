#!/bin/sh
set -euo pipefail

# Load approved namespaces from ConfigMap (mounted at /config)
if [ -f /config/approved_namespaces ]; then
  APPROVED_NAMESPACES=$(cat /config/approved_namespaces | tr ',' ' ')
else
  APPROVED_NAMESPACES="argocd"
fi

echo "=== Cleanup Job Started ==="
echo "Approved namespaces: $APPROVED_NAMESPACES"
echo "==========================="

ALL_NAMESPACES=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort -u)

for ns in $ALL_NAMESPACES; do
  if echo "$APPROVED_NAMESPACES" | grep -qw "$ns"; then
    echo "✅ Retaining namespace: $ns"
    continue
  fi

  LB_SERVICES=$(kubectl get svc -n "$ns" -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' || true)

  if [ -n "$LB_SERVICES" ]; then
    for svc in $LB_SERVICES; do
      echo "🚨 Deleting LoadBalancer Service: $svc (namespace: $ns)"
      kubectl delete svc "$svc" -n "$ns" --ignore-not-found
    done
  fi
done

echo "=== Cleanup Completed ==="
