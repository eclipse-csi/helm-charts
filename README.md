# helm-charts

Eclipse Common Security Infrastructure (CSI) helm charts

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```bash
helm repo add eclipse-csi  https://eclipse-csi.github.io/helm-charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
eclipse-csi` to see the charts.

## Dependencies

### Otterdog Dependencies

Otterdog requires the following dependencies to function properly:

- **MongoDB**: Used for data storage and persistence
- **Redis or Valkey**: Used for caching and session management

Additionally, otterdog requires **ghproxy**, which is provided within the otterdog helm charts.

**Important Security Note**: ghproxy requires Redis/Valkey to be configured without authentication/authorization. Ensure that this Redis/Valkey instance is only accessible by the otterdog deployment and is not exposed to external networks or unauthorized services.

## Charts

You can search all eclipse-csi charts using following command:

```bash
helm search repo eclipse-csi
```

## Contributing

See https://github.com/eclipse-csi/helm-charts
