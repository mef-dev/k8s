# servicehost

MEF.DEV application chart, version 2.0.1.

```bash
helm upgrade --install servicehost helm/charts/servicehost --namespace mef-dev --create-namespace -f helm/values/servicehost.yaml
```

Read [installation](../../../README.md#1-prepare-the-repository-and-namespace) before running the command.
Default container: `digitalbss/servicehost`; Service port `7000`.
Use the complete configuration in [servicehost.yaml](../../values/servicehost.yaml), enforced by [values.schema.json](values.schema.json)
and described in the [shared values contract](../../../README.md#configuration).

Application credentials must exist as Kubernetes Secrets.
See [migration](../../../README.md#upgrade-and-migration) for the 2.0 values contract.

Full application settings are under `config.appsettings`. See [application configuration](../../../README.md#application-configuration) for feature activation, external Secrets and mounted configuration.

The supplied values reference shared PVCs from the `storage` release. Install that
release first; see the [mount mapping](../../../README.md#storage-and-databases).

The chart's `values.yaml` is only a pointer. Always pass the complete
[servicehost.yaml](../../values/servicehost.yaml) with `-f`; chart-only installation is rejected by schema validation.
