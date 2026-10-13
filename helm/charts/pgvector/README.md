# pgvector

Standalone MEF.DEV chart, version 2.0.0.

```bash
helm upgrade --install pgvector helm/charts/pgvector --namespace mef-dev --create-namespace -f helm/values/pgvector.yaml
```

Read [installation](../../../README.md#1-prepare-the-repository-and-namespace) before running the command.
Default container: `pgvector/pgvector`; Service port `5432`.
All values are documented in [values.yaml](values.yaml), enforced by [values.schema.json](values.schema.json)
and described in the [shared values contract](../../../README.md#configuration).

Application credentials must exist as Kubernetes Secrets. No private environment values are included.
See [migration](../../../README.md#upgrade-and-migration) for the 2.0 values contract.
