# ghproxy

![Version: 0.6.0][version-badge] <!-- x-release-please-version -->
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v20251030-0e4d5be42](https://img.shields.io/badge/AppVersion-v20251030--0e4d5be42-informational?style=flat-square)

A Helm chart for ghproxy

## Installation

`ghproxy` is a [caching reverse proxy for the GitHub API](https://github.com/kubernetes/test-infra/tree/master/ghproxy).
By default it caches on a disk volume (`cacheBackend: disk`); Redis/Valkey is still
supported (`cacheBackend: redis`). It is deployed as a stand-alone chart, or as a sub-chart
dependency of the `otterdog` chart.

Add the Eclipse CSI Helm repository:

```console
helm repo add eclipse-csi https://eclipse-csi.github.io/helm-charts
helm repo update
```

Install the chart with the release name `ghproxy`:

```console
helm install ghproxy eclipse-csi/ghproxy \
  --namespace ghproxy --create-namespace
```

Provide your own configuration with a values file:

```console
helm install ghproxy eclipse-csi/ghproxy \
  --namespace ghproxy --create-namespace \
  -f my-values.yaml
```

Or override individual values on the command line:

```console
helm install ghproxy eclipse-csi/ghproxy \
  --namespace ghproxy --create-namespace \
  --set redisAddress=my-redis:6379 \
  --set throttlingTimeMs=50
```

Upgrade an existing release:

```console
helm upgrade ghproxy eclipse-csi/ghproxy \
  --namespace ghproxy -f my-values.yaml
```

Uninstall the release:

```console
helm uninstall ghproxy --namespace ghproxy
```

### Upgrading to 0.6.0

0.6.0 switches the default cache backend from `redis` to `disk` and the cache PVC from
`ReadWriteOnce` to `ReadWriteMany` (5Gi). Kubernetes does not allow changing the access
modes of an existing PVC, so `helm upgrade` fails on `<release>-ghproxy-cache`. That PVC
held no data with the `redis` backend, so it can be deleted before upgrading:

```console
kubectl -n <namespace> delete deployment <release>-ghproxy
kubectl -n <namespace> delete pvc <release>-ghproxy-cache
helm upgrade ...
```

Alternatively keep the previous behaviour with `cacheBackend: redis` and
`persistence.accessModes: [ReadWriteOnce]`.

> **Note:** with `cacheBackend: redis`, ghproxy needs a Redis/Valkey instance to cache against. If none is deployed
> alongside it (e.g. when installed standalone, without the otterdog parent chart's
> `valkey` sub-chart), set `redisAddress` explicitly. See the [Secrets](#secrets) section
> below for how the Redis password is supplied, and the [Values](#values) section for all
> other options.

## Secrets

The only secret this chart manages is the Redis/Valkey password (only with
`cacheBackend: redis`), supplied in one of two
mutually exclusive ways, controlled by `vault.enabled`.

### Non-Vault mode (`vault.enabled: false`)

`redisPassword` is read from `values.yaml` and rendered into a `<release>-redis-auth`
Kubernetes `Secret` by `templates/secret.yaml`. This is intended for local/dev use only —
do not commit real secrets. Leave `redisPassword` empty to run against an unauthenticated
Redis/Valkey instance (no secret/volume is mounted in that case).

### Vault mode (`vault.enabled: true`)

The password is synced from HashiCorp Vault by the
[Vault Secrets Operator (VSO)](https://developer.hashicorp.com/vault/docs/platform/k8s/vso).
`templates/vault-static-secret.yaml` creates a `VaultAuth` and a `VaultStaticSecret` that
syncs into the `<release>-redis-auth` Kubernetes `Secret`.

The key is read from a single Vault KV v2 entry:

```
<vault.secretMount>/data/<vault.secretPath>     e.g. csi/data/otterdog/dev
```

| Vault key | Kubernetes Secret (VSO destination) | Consumed as |
| --------- | ----------------------------------- | ----------- |
| `valkey_password` | `<release>-redis-auth` (key `redis-password`) | file `/etc/ghproxy-redis/redis-password` (arg `--redis-secret-file`) |

Notes:

- `vault.serviceAccountName` (default `secrets-manager-sa`) is the Kubernetes
  **ServiceAccount used to authenticate the `VaultAuth` login**.
- Vault connection settings (`vault.authPath`, `vault.role`, `vault.secretMount`,
  `vault.secretPath`) must match a Kubernetes auth role in Vault that authorizes
  `vault.serviceAccountName` in this release's namespace.
- `redisUsername` defaults to `"default"` whenever a password is in use (`redisPassword`
  set or `vault.enabled: true`) and no explicit username is given — matching Redis/Valkey's
  own default ACL user name.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| nameOverride | string | `""` |  |
| fullnameOverride | string | `""` |  |
| selectorNameOverride | string | `""` |  |
| image.repository | string | `"us-docker.pkg.dev/k8s-infra-prow/images/ghproxy"` |  |
| image.tag | string | `"v20251030-0e4d5be42"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| cacheBackend | string | `"disk"` | Cache backend used by ghproxy: `redis`, `disk` or `memory`. `redis` shares one Redis connection across all requests; under concurrent load this can panic ("slice bounds out of range [:N] with capacity 4096") and leave the proxy hanging on the affected URLs until it is restarted. `disk` (default) stores the cache under persistence.mountPath and does not have this problem. |
| cacheSizeGB | int | `1` |  |
| redisAddress | string | `""` |  |
| redisUsername | string | `""` |  |
| redisPassword | string | `"changeme"` |  |
| legacyDisableDiskCachePartitionsByAuthHeader | bool | `true` | Disk cache only. When false, ghproxy keeps one cache directory per Authorization header, and only deletes it if the client sends X-PROW-TOKEN-EXPIRES-AT. otterdog does not send it and uses GitHub App tokens that change every hour, so the volume would fill up. Keep true: one shared cache, which is also how the redis backend behaves. |
| throttlingTimeMs | int | `10` |  |
| getThrottlingTimeMs | int | `10` |  |
| logLevel | string | `"info"` |  |
| extraArgs | list | `[]` |  |
| service.port | int | `8888` |  |
| healthPort | int | `8081` | Port for the /healthz and /healthz/ready endpoints (--health-port) |
| livenessProbe | object | `{"failureThreshold":5,"httpGet":{"path":"/rate_limit","port":"http"},"initialDelaySeconds":30,"periodSeconds":30,"timeoutSeconds":10}` | Liveness probe. It sends a request through the proxy itself (GET /rate_limit, which GitHub does not count against the rate limit), so the pod is restarted when ghproxy stops answering. A probe on the health port only would not catch that. Set to null to disable. |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/healthz/ready","port":"health"},"periodSeconds":10,"timeoutSeconds":5}` | Readiness probe. Set to null to disable. |
| persistence.enabled | bool | `true` |  |
| persistence.mountPath | string | `"/cache/"` |  |
| persistence.size | string | `"5Gi"` |  |
| persistence.storageClassName | string | `""` |  |
| persistence.accessModes | list | `["ReadWriteMany"]` | Access modes for the PVC. ReadWriteMany lets the new pod mount the cache while the old one is still running during a rolling update; it needs a storage class that supports it. |
| persistence.existingClaim | string | `""` | Use an existing PVC instead of creating one; when set, no PVC is created by this chart |
| persistence.volumeName | string | `""` | Bind to a specific, statically-provisioned PersistentVolume by name |
| persistence.selector | object | `{}` | Label selector to match a pre-existing PersistentVolume, e.g. matchLabels |
| persistence.annotations | object | `{}` | Extra annotations to add to the PVC |
| persistence.labels | object | `{}` | Extra labels to add to the PVC, in addition to the chart's standard labels |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.name | string | `""` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| vault.enabled | bool | `false` | Enable Vault Secrets Operator (VSO) integration for the redis-password secret |
| vault.authPath | string | `""` | Vault Kubernetes auth path, e.g. auth/kubernetes-<instance>-<env>-<namespace> |
| vault.role | string | `""` | Vault role for authentication, e.g. <instance>-<env>_<namespace>_role |
| vault.secretMount | string | `"csi"` | Vault KV v2 secrets engine mount path, e.g. csi |
| vault.secretPath | string | `"otterdog/dev"` | Full path inside the mount, e.g. otterdog/<env> → csi/data/otterdog/staging |
| vault.serviceAccountName | string | `"secrets-manager-sa"` | Service account name for the Vault Kubernetes auth method (optional; defaults to "secrets-manager-sa") |
| vault.operator | object | `{"refreshAfter":"30s"}` | VSO operator configuration |
| vault.operator.refreshAfter | string | `"30s"` | How often VSO syncs the secret from Vault (e.g. 30s, 1m) |

<!-- x-release-please-start-version -->
[version-badge]: https://img.shields.io/badge/Version-0.6.0%2Dinformational?style=flat-square
<!-- x-release-please-end -->
