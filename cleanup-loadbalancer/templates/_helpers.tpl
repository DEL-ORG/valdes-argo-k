{{/*
Return approved namespaces as a comma-separated string
*/}}
{{- define "cleanup-loadbalancer.approvedNamespaces" -}}
{{ join "," .Values.approvedNamespaces }}
{{- end }}
