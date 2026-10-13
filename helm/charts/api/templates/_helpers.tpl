{{/*
Expand the name of the chart.
*/}}
{{- define "api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "api.fullname" -}}
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
{{- define "api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
{{ include "api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "api.image" -}}
{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end -}}
{{- define "api.validate" -}}
{{- if and .Values.config.enabled (not .Values.config.existingSecret) (not .Values.config.existingConfigMap) (hasKey .Values.config.data "appsettings.json") -}}
{{- $raw := index .Values.config.data "appsettings.json" | mustFromJson -}}
{{- if not (kindIs "map" $raw) -}}{{- fail "appsettings.json must be a JSON object" -}}{{- end -}}
{{- end -}}

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

{{- define "api.configName" -}}
{{ printf "%s-config" (include "api.fullname" . | trunc 56 | trimSuffix "-") }}
{{- end -}}

{{- define "api.headlessName" -}}
{{ printf "%s-headless" (include "api.fullname" . | trunc 54 | trimSuffix "-") }}
{{- end -}}

{{- define "api.appsettings" -}}
{{- $cfg := deepCopy .Values.config.appsettings -}}
{{- $sinks := list -}}
{{- range $index, $sink := $cfg.Serilog.WriteTo -}}
  {{- $disabled := false -}}
  {{- range $.Values.config.disabledLogSinks -}}{{- if eq (int .) $index -}}{{- $disabled = true -}}{{- end -}}{{- end -}}
  {{- if not $disabled -}}{{- $sinks = append $sinks $sink -}}{{- end -}}
{{- end -}}
{{- $_ := set $cfg.Serilog "WriteTo" $sinks -}}
{{- $cfg | mustToPrettyJson -}}
{{- end -}}
