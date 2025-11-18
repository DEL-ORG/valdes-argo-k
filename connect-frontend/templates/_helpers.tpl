{{- define "connect-frontend.fullname" -}}
{{- if .Values.nameOverride }}{{ .Values.nameOverride }}{{- else -}}
{{ include "helm.sh/name" . | default .Chart.Name }}
{{- end -}}
{{- end -}}

{{- define "connect-frontend.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
