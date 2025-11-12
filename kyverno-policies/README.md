# Kyverno Policies — Cluster Governance (Ticket 568)

This repository contains a collection of Kyverno `ClusterPolicy` YAML files that implement the governance rules requested in ticket #568.

## High level implemented rules
1. Critical Namespace Protection (deny deletion of protected namespaces)
2. Disallow `LoadBalancer` Services except `traefik`
3. Replica count limited to max 2 (exclude connect-apps and traefik)
4. PV & PVC limits (<= 4Gi) — PVCs exclude `connect-apps`
5. Label requirements in `connect-apps` (app=connect + service=<deployment-name>)
6. Deployment controls in `connect-apps` (name must `connect-*` and use specific service account)
7. Image registry enforcement for `connect-apps`
8. Resource requests & limits required in `connect-apps`
9. Deny `:latest` tags and require immutable `vX.Y.Z` style tags
10. Namespace ResourceQuota generation (non-system namespaces)
11. Secret management: prohibit `stringData` & plaintext env values
12. Ingress TLS enforcement and approved cert secrets only

## Before you apply
1. Set correct values:
   - `CONNECT_SERVICE_ACCOUNT` in `08-connect-apps-deployment-controls.yaml`
   - `APPROVED_CERT_SECRET_1`, `APPROVED_CERT_SECRET_2` (and more if needed) in `16-ingress-require-tls-and-approved-secret.yaml`
2. Review `05-pvc-capacity-limit.yaml` and `04-pv-capacity-limit.yaml` if your storage requests use different units (Mi, Ti). The policies allow explicit sizes of 1Gi,2Gi,3Gi,4Gi — adjust if necessary.
3. Confirm Kyverno is installed and healthy:
   ```bash
   kubectl -n kyverno rollout status deployment/kyverno
