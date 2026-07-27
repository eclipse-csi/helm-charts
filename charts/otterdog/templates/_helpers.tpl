{{/*
Expand the name of the chart.
*/}}
{{- define "webapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "webapp.fullname" -}}
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
Image pull policy. Forces "Always" when image.tag is "dev" (mutable/floating tag),
otherwise uses image.pullPolicy as configured.
*/}}
{{- define "webapp.image.pullPolicy" -}}
{{- if eq .Values.image.tag "dev" -}}
Always
{{- else -}}
{{- .Values.image.pullPolicy -}}
{{- end -}}
{{- end -}}

{{/*
Name for the dedicated Ingress/Route restricted to protectInit.path.
Format: otterdog-protect-init-<env>, where <env> is derived by stripping the
"otterdog-" release-name prefix (releases follow <chart>-<env>, e.g. otterdog-staging).
*/}}
{{- define "otterdog.protectInit.fullname" -}}
{{- printf "otterdog-protect-init-%s" (trimPrefix "otterdog-" .Release.Name) -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "webapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "webapp.labels" -}}
helm.sh/chart: {{ include "webapp.chart" . }}
{{ include "webapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "webapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "webapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Valkey host.
Auto-derived from the valkey subchart service (<release>-valkey.<namespace>).
Override with config.valkeyUri.
*/}}
{{- define "otterdog.valkey.host" -}}
{{- if .Values.config.valkeyUri -}}
{{- $uri := .Values.config.valkeyUri -}}
{{- $host := regexFind "@([^:/]+)" $uri | trimPrefix "@" -}}
{{- if not $host -}}
{{- $host = regexFind "^([^:@/]+)" (regexReplaceAll "^redis://(.*)" $uri "${1}") -}}
{{- end -}}
{{- $host -}}
{{- else -}}
{{- printf "%s-valkey.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}


{{/*
Valkey port.
Auto-derived as 6379, or parsed from config.valkeyUri if set.
*/}}
{{- define "otterdog.valkey.port" -}}
{{- if .Values.config.valkeyUri -}}
{{- regexFind ":([0-9]+)$" .Values.config.valkeyUri | trimPrefix ":" | default "6379" -}}
{{- else -}}
{{- "6379" -}}
{{- end -}}
{{- end -}}


{{/*
Full Valkey URI.
Auto-derived from the valkey subchart service (<release>-valkey.<namespace>).
When valkeyUri is not set, valkeyUsername/valkeyPassword are injected as credentials.
Override with config.valkeyUri.
*/}}
{{- define "otterdog.valkey.uri" -}}
{{- if .Values.config.valkeyUri -}}
{{- .Values.config.valkeyUri -}}
{{- else -}}
{{- $pass := .Values.config.valkeyPassword -}}
{{- if and (not $pass) .Values.valkey.auth.enabled -}}
{{- $pass = .Values.valkey.auth.password -}}
{{- end -}}
{{- $user := .Values.config.valkeyUsername | default (ternary "default" "" (not (empty $pass))) -}}
{{- $auth := "" -}}
{{- if and $user $pass -}}
{{- $auth = printf "%s:%s@" $user $pass -}}
{{- else if $user -}}
{{- $auth = printf "%s@" $user -}}
{{- end -}}
{{- printf "redis://%s%s:%s" $auth (include "otterdog.valkey.host" .) (include "otterdog.valkey.port" .) -}}
{{- end -}}
{{- end -}}

{{/*
Builds the redis_uri text value for a VSO transformation template.
When valkey.auth.enabled, the password placeholder {{ .Secrets.valkey_password }}
is left as a literal string for VSO to resolve at sync time.
When auth is disabled, returns a fully static URI from Helm values.
  username (optional) : config.valkeyUsername
  host / port         : otterdog.valkey.host / otterdog.valkey.port
*/}}
{{- define "otterdog.valkey.vso.uri" -}}
{{- if .Values.valkey.auth.enabled -}}
{{- $user := .Values.config.valkeyUsername | default "default" -}}
{{- printf "redis://%s:{{ .Secrets.valkey_password }}@%s:%s"
    $user
    (include "otterdog.valkey.host" .)
    (include "otterdog.valkey.port" .) -}}
{{- else -}}
{{- include "otterdog.valkey.uri" . -}}
{{- end -}}
{{- end -}}


{{/*
GHProxy host.
Auto-derived from the ghproxy subchart service (<release>-ghproxy.<namespace>).
Override with config.ghProxyUri.
*/}}
{{- define "otterdog.ghproxy.host" -}}
{{- if .Values.config.ghProxyUri -}}
{{- regexFind "^([^:/]+)" (regexReplaceAll "^https?://(.*)" .Values.config.ghProxyUri "${1}") -}}
{{- else -}}
{{- printf "%s-ghproxy.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
GHProxy port.
Auto-derived as 8888, or parsed from config.ghProxyUri if set.
*/}}
{{- define "otterdog.ghproxy.port" -}}
{{- if .Values.config.ghProxyUri -}}
{{- regexFind ":([0-9]+)" .Values.config.ghProxyUri | trimPrefix ":" | default "8888" -}}
{{- else -}}
{{- "8888" -}}
{{- end -}}
{{- end -}}

{{/*
Full GHProxy URI.
Auto-derived from the ghproxy subchart service (<release>-ghproxy.<namespace>).
Override with config.ghProxyUri.
*/}}
{{- define "otterdog.ghproxy.uri" -}}
{{- .Values.config.ghProxyUri | default (printf "http://%s:%s" (include "otterdog.ghproxy.host" .) (include "otterdog.ghproxy.port" .)) -}}
{{- end -}}

{{/*
MongoDB host.
Auto-derived from the mongodb subchart service (<release>-mongodb.<namespace>).
Override with config.mongoHost.
*/}}
{{- define "otterdog.mongodb.host" -}}
{{- .Values.config.mongoHost | default (printf "%s-mongodb.%s.svc.cluster.local" .Release.Name .Release.Namespace) -}}
{{- end -}}


{{/*
MongoDB port.
Override with config.mongoPort.
*/}}
{{- define "otterdog.mongodb.port" -}}
{{- .Values.config.mongoPort | default "27017" -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret created by the Vault Secrets Operator.
Override with vault.operator.destinationSecret, otherwise defaults to <fullname>-vault-secrets.
*/}}
{{- define "otterdog.vault.secretName" -}}
{{- default (printf "%s-vault-secrets" (include "webapp.fullname" .)) .Values.vault.operator.destinationSecret -}}
{{- end -}}

{{/*
Name of the dedicated MongoDB credentials Secret created by VSO.
Used by the mongodb subchart as existingSecret when vault is enabled.
*/}}
{{- define "otterdog.mongodb.credentialsSecretName" -}}
{{- printf "%s-mongodb-credentials" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the GitHub config token.
*/}}
{{- define "otterdog.secret.configToken" -}}
{{- printf "%s-config-token" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the GitHub webhook secret.
*/}}
{{- define "otterdog.secret.webhookSecret" -}}
{{- printf "%s-webhook-secret" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the GitHub App private key.
*/}}
{{- define "otterdog.secret.appPrivateKey" -}}
{{- printf "%s-app-private-key" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the Dependency-Track API token.
*/}}
{{- define "otterdog.secret.dependencyTrackToken" -}}
{{- printf "%s-dependency-track-token" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the MongoDB URI.
*/}}
{{- define "otterdog.secret.mongoUri" -}}
{{- printf "%s-mongo-uri" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Name of the Kubernetes Secret holding the Redis/Valkey URI.
*/}}
{{- define "otterdog.secret.redisUri" -}}
{{- printf "%s-valkey-uri" (include "webapp.fullname" .) -}}
{{- end -}}

{{/*
Reusable guard for the first customUser entry (returns an empty dict if customUsers is nil or empty).
*/}}
{{- define "otterdog.mongodb.firstUser" -}}
{{- $users := .Values.mongodb.customUsers | default list -}}
{{- if gt (len $users) 0 -}}
{{- index $users 0 | toJson -}}
{{- else -}}
{{- dict | toJson -}}
{{- end -}}
{{- end -}}

{{/*
MongoDB connection username with safe fallbacks.
Priority: config.mongoUsername → customUsers[0].name → auth.rootUsername → ""
*/}}
{{- define "otterdog.mongodb.username" -}}
{{- $user := include "otterdog.mongodb.firstUser" . | fromJson -}}
{{- coalesce .Values.config.mongoUsername (get $user "name") .Values.mongodb.auth.rootUsername "" -}}
{{- end -}}

{{/*
MongoDB database name with safe fallbacks.
Priority: config.mongoDatabase → customUsers[0].database → "otterdog"
*/}}
{{- define "otterdog.mongodb.database" -}}
{{- $user := include "otterdog.mongodb.firstUser" . | fromJson -}}
{{- coalesce .Values.config.mongoDatabase (get $user "database") "otterdog" -}}
{{- end -}}

{{/*
Auth source database for the mongo connection.
customUsers  : the app user only exists in its own database → authSource = that database.
root fallback (no customUsers) : MONGO_INITDB_ROOT_USERNAME/PASSWORD always create the root
  user in "admin", regardless of config.mongoDatabase → authSource = "admin".
*/}}
{{- define "otterdog.mongodb.authSource" -}}
{{- $user := include "otterdog.mongodb.firstUser" . | fromJson -}}
{{- if get $user "name" -}}
{{- include "otterdog.mongodb.database" . -}}
{{- else -}}
admin
{{- end -}}
{{- end -}}

{{/*
Build the full MongoDB connection URI with safe fallbacks.
Priority:
  username : config.mongoUsername → customUsers[0].name → auth.rootUsername → ""
  password : config.mongoPassword → customUsers[0].password → auth.rootPassword → ""
  database : config.mongoDatabase → customUsers[0].database → "otterdog"
customUsers may be nil or empty — all accesses are guarded.
mongodb.auth.enabled=false → no credentials in the URI at all.
mongodb.auth.enabled=true  → credentials plus an explicit authSource (see otterdog.mongodb.authSource).
*/}}
{{- define "otterdog.mongodb.uri" -}}
{{- if not .Values.mongodb.auth.enabled -}}
{{- printf "mongodb://%s:%s/%s" (include "otterdog.mongodb.host" .) (include "otterdog.mongodb.port" .) (include "otterdog.mongodb.database" .) -}}
{{- else -}}
{{- $user := include "otterdog.mongodb.firstUser" . | fromJson -}}
{{- $username := coalesce .Values.config.mongoUsername (get $user "name") .Values.mongodb.auth.rootUsername "" -}}
{{- $password := coalesce .Values.config.mongoPassword (get $user "password") .Values.mongodb.auth.rootPassword "" -}}
{{- printf "mongodb://%s:%s@%s:%s/%s?authSource=%s"
    $username $password
    (include "otterdog.mongodb.host" .)
    (include "otterdog.mongodb.port" .)
    (include "otterdog.mongodb.database" .)
    (include "otterdog.mongodb.authSource" .) -}}
{{- end -}}
{{- end -}}

{{/*
Builds the mongo_uri text for a VSO transformation template using the app-user password.
The password placeholder {{ .Secrets.mongodb_app_password }} is left as a literal string
for VSO to resolve at sync time. authSource is the app user's own database.
*/}}
{{- define "otterdog.mongodb.vso.uri.app" -}}
{{- printf "mongodb://%s:{{ .Secrets.mongodb_app_password }}@%s:%s/%s?authSource=%s"
    (include "otterdog.mongodb.username" .)
    (include "otterdog.mongodb.host" .)
    (include "otterdog.mongodb.port" .)
    (include "otterdog.mongodb.database" .)
    (include "otterdog.mongodb.database" .) -}}
{{- end -}}

{{/*
Builds the mongo_uri text for a VSO transformation template using the root password.
The password placeholder {{ .Secrets.mongodb_root_password }} is left as a literal string
for VSO to resolve at sync time. authSource is always "admin": MONGO_INITDB_ROOT_USERNAME/PASSWORD
always create the root user there, regardless of config.mongoDatabase.
*/}}
{{- define "otterdog.mongodb.vso.uri.root" -}}
{{- printf "mongodb://%s:{{ .Secrets.mongodb_root_password }}@%s:%s/%s?authSource=admin"
    (include "otterdog.mongodb.username" .)
    (include "otterdog.mongodb.host" .)
    (include "otterdog.mongodb.port" .)
    (include "otterdog.mongodb.database" .) -}}
{{- end -}}

{{/*
Builds the mongo_uri text for a VSO transformation template with no credentials at all,
used when mongodb.auth.enabled is false.
*/}}
{{- define "otterdog.mongodb.vso.uri.noauth" -}}
{{- printf "mongodb://%s:%s/%s"
    (include "otterdog.mongodb.host" .)
    (include "otterdog.mongodb.port" .)
    (include "otterdog.mongodb.database" .) -}}
{{- end -}}