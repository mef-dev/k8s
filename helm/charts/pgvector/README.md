# pgvector

Standalone MEF.DEV chart, version 2.0.1.

```bash
helm upgrade --install pgvector helm/charts/pgvector --namespace mef-dev --create-namespace -f helm/values/pgvector.yaml
```

Read [installation](../../../README.md#1-prepare-the-repository-and-namespace) before running the command.
Default container: `pgvector/pgvector`; Service port `5432`.
Use the complete configuration in [pgvector.yaml](../../values/pgvector.yaml), enforced by [values.schema.json](values.schema.json)
and described in the [shared values contract](../../../README.md#configuration).

Application credentials must exist as Kubernetes Secrets.
See [migration](../../../README.md#upgrade-and-migration) for the 2.0 values contract.

The chart's `values.yaml` is only a pointer. Always pass the complete
[pgvector.yaml](../../values/pgvector.yaml) with `-f`; chart-only installation is rejected by schema validation.
