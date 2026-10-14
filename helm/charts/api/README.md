# api

MEF.DEV application chart, version 2.0.1. Public name for UCP API.

```bash
helm upgrade --install api helm/charts/api --namespace mef-dev --create-namespace -f helm/values/api.yaml
```

Read [installation](../../../README.md#1-prepare-the-repository-and-namespace) before running the command.
Default container: `digitalbss/api`; Service port `5000`.
Use the complete configuration in [api.yaml](../../values/api.yaml), enforced by [values.schema.json](values.schema.json)
and described in the [shared values contract](../../../README.md#configuration).

Application credentials must exist as Kubernetes Secrets. No private environment values are included.
See [migration](../../../README.md#upgrade-and-migration) for the 2.0 values contract.

Full application settings are under `config.appsettings`. See [application configuration](../../../README.md#application-configuration) for feature activation, external Secrets and mounted configuration.

The supplied values reference shared PVCs from the `storage` release. Install that
release first; see the [mount mapping](../../../README.md#storage-and-databases).

Microsoft Entra ID is the primary sign-in method. Configure your own App Registration
as described in [installation step 2](../../../README.md#microsoft-entra-id).
The supplied values preserve the image's matching encrypted configuration/key pair.

The chart's `values.yaml` is only a pointer. Always pass the complete
[api.yaml](../../values/api.yaml) with `-f`; chart-only installation is rejected by schema validation.
