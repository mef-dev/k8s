# knowledge-graph

MEF.DEV application chart, version 2.0.1.

```bash
helm upgrade --install knowledge-graph helm/charts/knowledge-graph --namespace mef-dev --create-namespace -f helm/values/knowledge-graph.yaml
```

Read [installation](../../../README.md#1-prepare-the-repository-and-namespace) before running the command.
Default container: `digitalbss/knowledge-graph`; Service port `80`.
Use the complete configuration in [knowledge-graph.yaml](../../values/knowledge-graph.yaml), enforced by [values.schema.json](values.schema.json)
and described in the [shared values contract](../../../README.md#configuration).

Application credentials must exist as Kubernetes Secrets. No private environment values are included.
See [migration](../../../README.md#upgrade-and-migration) for the 2.0 values contract.

The supplied values mount the shared `back` PVC at `/usr/share/nginx/html/packages`.
Install the `storage` release first. The image startup command requires permission to
change the mounted directory mode. See the root README for the shared-volume layout.

The chart's `values.yaml` is only a pointer. Always pass the complete
[knowledge-graph.yaml](../../values/knowledge-graph.yaml) with `-f`; chart-only installation is rejected by schema validation.
