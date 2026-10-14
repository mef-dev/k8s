# db-update

Uses `digitalbss/db-update` to apply the MEF schema to an existing SQL Server.
See [database update](../../../README.md#database-update). The supplied installation values enable migrations;
review `helm/values/db-update.yaml` and choose the run ID before this command.

```bash
helm upgrade --install db-update helm/charts/db-update --namespace mef-dev \
  -f helm/values/db-update.yaml \
  --wait --wait-for-jobs --timeout 35m
```

Back up first. Use a new runId only for an intentional new execution; do not run migrations concurrently.
Default password source: `mssql-auth/password`. The wrapper bypasses the image's password-printing,
non-terminating CMD, checks exit codes and does not automatically retry failed SQL mutations.

`filegroups.partition10`, `partition10d`, `partition10d14` and `partition10d14s` map
to the four partition functions. Zero selects the image default. Installation values
use one first-dimension partition for each function; preserve an existing database layout.

The chart's `values.yaml` is only a pointer. Always pass the complete
[db-update.yaml](../../values/db-update.yaml) with `-f`; chart-only installation is rejected by schema validation.
