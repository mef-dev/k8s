# storage

Creates the shared `front`, `back` and `api-config` PVCs in the Helm release namespace.
Select an RWX-capable StorageClass in [storage.yaml](../../values/storage.yaml).

```bash
helm upgrade --install storage helm/charts/storage --namespace mef-dev --create-namespace --values helm/values/storage.yaml
```

Install this release before the applications. Claims use `ReadWriteMany` and are retained
on Helm uninstall by default. Database PVCs belong to their respective database charts.
For an existing claim managed outside this release, set its `create: false`; its name
must still be `front`, `back` or `api-config` as referenced by the application values.
See [installation and mount mapping](../../../README.md#storage-and-databases).
