{{/*
Expand the name of the chart.
*/}}
{{- define "plantuml.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "plantuml.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "plantuml.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "plantuml.labels" -}}
helm.sh/chart: {{ include "plantuml.chart" . }}
{{ include "plantuml.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "plantuml.selectorLabels" -}}
app.kubernetes.io/name: {{ include "plantuml.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "plantuml.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "plantuml.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "plantuml.image" -}}
{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end -}}
{{- define "plantuml.validate" -}}
{{- if and .Values.config.existingConfigMap .Values.config.existingSecret -}}
{{- fail "config.existingConfigMap and config.existingSecret are mutually exclusive" -}}
{{- end -}}
{{- if and .Values.persistence.enabled (gt (int .Values.replicaCount) 1) (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}
{{- fail "Multiple replicas sharing a PVC require ReadWriteMany; this chart does not create per-replica claims" -}}
{{- end -}}
{{- if and (eq .Values.networking.mode "gateway") (or (empty .Values.gateway.parentRefs) (empty .Values.gateway.hostnames)) -}}
{{- fail "gateway mode requires explicit parentRefs and hostnames" -}}
{{- end -}}
{{- if and (eq .Values.networking.mode "ingress") (or (empty .Values.ingress.className) (empty .Values.ingress.hosts)) -}}
{{- fail "ingress mode requires explicit className and hosts" -}}
{{- end -}}
{{- if or (hasKey .Values.ingress "enabled") (hasKey .Values.gateway "enabled") -}}
{{- fail "Use networking.mode=none|ingress|gateway, not ingress.enabled or gateway.enabled; see migration guide" -}}
{{- end -}}
{{- if and .Values.persistence.enabled .Values.autoscaling.enabled (not (has "ReadWriteMany" .Values.persistence.accessModes)) -}}
{{- fail "HPA with a shared PVC requires ReadWriteMany" -}}
{{- end -}}
{{- end -}}

{{- define "plantuml.configName" -}}
{{ printf "%s-config" (include "plantuml.fullname" . | trunc 56 | trimSuffix "-") }}
{{- end -}}

{{- define "plantuml.headlessName" -}}
{{ printf "%s-headless" (include "plantuml.fullname" . | trunc 54 | trimSuffix "-") }}
{{- end -}}
