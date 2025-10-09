#!/usr/bin/env bash
kubectl run -it redis-client --rm --image=bitnami/redis:latest -n redis-cluster -- bash
