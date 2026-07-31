{{/*
Expand the name of the chart.
*/}}
{{- define "pia.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pia.fullname" -}}
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
{{- define "pia.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pia.labels" -}}
helm.sh/chart: {{ include "pia.chart" . }}
{{ include "pia.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pia.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pia.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image the one-off sync job runs. Defaults to the app image, so the sync CLI
matches the deployed app and its database schema.
*/}}
{{- define "pia.sync.image" -}}
{{- if .Values.sync.image -}}
{{- .Values.sync.image -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
DependencyTrack base URL for the sync job. The app is configured with the
/api/v1/bom upload endpoint; the CLI wants the base URL.
*/}}
{{- define "pia.sync.dtUrl" -}}
{{- if .Values.sync.dtUrl -}}
{{- .Values.sync.dtUrl -}}
{{- else -}}
{{- .Values.config.dependencyTrackUrl | trimSuffix "/" | trimSuffix "/api/v1/bom" -}}
{{- end -}}
{{- end }}

{{/*
Names of the existing secrets the sync job reads its credentials from. Each
defaults to a suffix of the release fullname.
*/}}
{{- define "pia.sync.dbSecretName" -}}
{{- .Values.sync.dbExistingSecret | default (printf "%s-db-cli" (include "pia.fullname" .)) -}}
{{- end }}

{{- define "pia.sync.dtApiSecretName" -}}
{{- .Values.sync.dtApiExistingSecret | default (printf "%s-dt-cli" (include "pia.fullname" .)) -}}
{{- end }}

{{- define "pia.sync.githubSecretName" -}}
{{- .Values.sync.githubExistingSecret | default (printf "%s-gh" (include "pia.fullname" .)) -}}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pia.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pia.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
