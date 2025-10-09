#!/usr/bin/env bash
set -e
NAMESPACE=redis-cluster
echo "Checking Redis Cluster pods..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=redis -o wide
echo "Cluster status:"
kubectl run -it redis-client --image=bitnami/redis:latest -n $NAMESPACE --rm -- bash -c \
  "redis-cli -h redis-cluster-headless -a $(kubectl get secret redis-password -n $NAMESPACE -o jsonpath='{.data.redis-password}' | base64 -d) cluster info"
