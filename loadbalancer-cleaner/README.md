## LoadBalancer Cleaner – Kustomize Deployment

## Overview

This project automates the cleanup of unauthorized LoadBalancer Services across Kubernetes clusters.
It runs as a CronJob that scans all namespaces, compares them against an approved list, and deletes unauthorized services.

This helps ensure that no developer or automation accidentally exposes public-facing load balancers outside approved namespaces.

The setup is built using Kustomize overlays for dev, test, and prod environments, with:

Different cron schedules per environment

Safe dry-run mode in development

Secure service account and RBAC

Configurable list of approved namespaces

## Folder Structure
loadbalancer-cleaner/
├── base/
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── role.yaml
│   ├── rolebinding.yaml
│   ├── configmap-script.yaml
│   ├── configmap-config.yaml
│   ├── cronjob.yaml
│   └── kustomization.yaml
│
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── test/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
│
└── README.md

## Base Components

1. Namespace

base/namespace.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: loadbalancer-cleaner

2. Service Account

base/serviceaccount.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: cleanup-sa
  namespace: loadbalancer-cleaner

3. RBAC Role

base/role.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cleanup-role
  namespace: loadbalancer-cleaner
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "delete"]

4. RoleBinding

base/rolebinding.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cleanup-binding
  namespace: loadbalancer-cleaner
subjects:
  - kind: ServiceAccount
    name: cleanup-sa
    namespace: loadbalancer-cleaner
roleRef:
  kind: Role
  name: cleanup-role
  apiGroup: rbac.authorization.k8s.io

5. ConfigMap (Approved Namespaces)

base/configmap-config.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: lb-cleaner-config
  namespace: loadbalancer-cleaner
data:
  approved-namespaces: "argocd,monitoring,production"

6. Script (Cleanup Logic)

base/configmap-script.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: lb-cleaner-script
  namespace: loadbalancer-cleaner
data:
  cleanup-lb-services.sh: |
    #!/bin/bash
    set -euo pipefail

    APPROVED_NAMESPACES=$(cat /config/approved-namespaces)
    IFS=',' read -r -a APPROVED_ARRAY <<< "$APPROVED_NAMESPACES"

    DRY_RUN=${DRY_RUN:-false}
    echo "Dry-run mode: $DRY_RUN"
    echo "Approved namespaces: ${APPROVED_ARRAY[@]}"
    echo "Checking for LoadBalancer services..."

    kubectl get svc --all-namespaces -o json | jq -r '
      .items[] | select(.spec.type=="LoadBalancer") |
      "\(.metadata.namespace) \(.metadata.name)"' | while read namespace svc; do

      if [[ ! " ${APPROVED_ARRAY[@]} " =~ " ${namespace} " ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[DRY-RUN] Would delete unauthorized LoadBalancer Service: ${namespace}/${svc}"
          kubectl delete svc "${svc}" -n "${namespace}" --dry-run=client
        else
          echo "Deleting unauthorized LoadBalancer Service: ${namespace}/${svc}"
          kubectl delete svc "${svc}" -n "${namespace}" --ignore-not-found
        fi
      else
        echo "Keeping authorized LoadBalancer Service: ${namespace}/${svc}"
      fi
    done

    echo "Cleanup complete."

7. CronJob

base/cronjob.yaml

apiVersion: batch/v1
kind: CronJob
metadata:
  name: loadbalancer-cleaner
  namespace: loadbalancer-cleaner
spec:
  schedule: "*/30 * * * *"
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: cleanup-sa
          restartPolicy: OnFailure
          containers:
          - name: lb-cleaner
            image: bitnami/kubectl:latest
            command: ["/bin/bash", "/scripts/cleanup-lb-services.sh"]
            env:
            - name: DRY_RUN
              value: "false"
            volumeMounts:
            - name: script
              mountPath: /scripts
            - name: config
              mountPath: /config
          volumes:
          - name: script
            configMap:
              name: lb-cleaner-script
              defaultMode: 0755
          - name: config
            configMap:
              name: lb-cleaner-config

8. Base Kustomization

base/kustomization.yaml

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - role.yaml
  - rolebinding.yaml
  - configmap-config.yaml
  - configmap-script.yaml
  - cronjob.yaml

## Environment Overlays

Each environment inherits from base/ and overrides its schedule, dry-run mode, and approved namespaces.

 Dev Overlay (overlays/dev/kustomization.yaml)
resources:
  - ../../base

patches:
  - target:
      kind: ConfigMap
      name: lb-cleaner-config
    patch: |-
      - op: replace
        path: /data/approved-namespaces
        value: "argocd,dev-tools"

  - target:
      kind: CronJob
      name: loadbalancer-cleaner
    patch: |-
      - op: replace
        path: /spec/schedule
        value: "*/5 * * * *"
      - op: replace
        path: /spec/jobTemplate/spec/template/spec/containers/0/env/0/value
        value: "true"


 Test Overlay (overlays/test/kustomization.yaml)

resources:
  - ../../base

patches:
  - target:
      kind: CronJob
      name: loadbalancer-cleaner
    patch: |-
      - op: replace
        path: /spec/schedule
        value: "*/15 * * * *"
      - op: replace
        path: /spec/jobTemplate/spec/template/spec/containers/0/env/0/value
        value: "false"

Prod Overlay (overlays/prod/kustomization.yaml)

resources:
  - ../../base

patches:
  - target:
      kind: CronJob
      name: loadbalancer-cleaner
    patch: |-
      - op: replace
        path: /spec/schedule
        value: "*/30 * * * *"
      - op: replace
        path: /spec/jobTemplate/spec/template/spec/containers/0/env/0/value
        value: "false"

## Testing the Deployment

1- Apply the Dev Overlay (Dry-Run Mode)
kubectl apply -k overlays/dev


Check the deployed objects:

kubectl get all -n loadbalancer-cleaner

2️-Trigger a Manual Job for Immediate Test
kubectl create job --from=cronjob/loadbalancer-cleaner manual-dryrun -n loadbalancer-cleaner


Check logs:

kubectl logs -l job-name=manual-dryrun -n loadbalancer-cleaner


Expected output:

Dry-run mode: true
Approved namespaces: argocd dev-tools
[DRY-RUN] Would delete unauthorized LoadBalancer Service: unauthorized/nginx
Cleanup complete.


* No services are deleted in dev mode.

* Promote to Test or Prod
Test Environment
kubectl apply -k overlays/test


Runs every 15 minutes

Executes real deletions

Production Environment
kubectl apply -k overlays/prod


Runs every 30 minutes

Executes real deletions

##  Dry-Run Behavior Summary
Environment	Schedule	DRY_RUN	Behavior
Dev	Every 5 min	true	Logs only (safe testing)
Test	Every 15 min	false	Deletes unauthorized LB services
Prod	Every 30 min	false	Deletes unauthorized LB services
 Notes & Best Practices

Ensure that the service account has sufficient RBAC permissions to list and delete services.

To audit what’s being deleted, consider integrating Slack/Mattermost notifications in the script later.

You can modify approved-namespaces in base/configmap-config.yaml or override it per overlay.

Always test new logic first in the dev overlay (dry-run).

## Cleanup

To delete all components:

kubectl delete -k overlays/dev
# or
kubectl delete -k overlays/test
kubectl delete -k overlays/prod

## Summary

This project gives you:

A modular Kustomize-managed CronJob

Secure RBAC + namespace isolation

Environment-specific control via overlays

Configurable dry-run mode for safe testing

Easy deployment and promotion between clusters