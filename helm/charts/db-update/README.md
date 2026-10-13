# db-update

Uses `digitalbss/db-update` to apply the MEF schema to an existing SQL Server.
See [database update](../../../README.md#database-update). Chart defaults disable migrations. The supplied installation values enable them;
review `helm/values/db-update.yaml` and choose the run ID before this command.

```bash
helm upgrade --install db-update helm/charts/db-update --namespace mef-dev \
  -f helm/values/db-update.yaml \
  --wait --wait-for-jobs --timeout 35m
```

Back up first. Use a new runId only for an intentional new execution; do not run migrations concurrently.
Default password source: `mssql-auth/password`. The wrapper bypasses the image's password-printing,
non-terminating CMD, checks exit codes and does not automatically retry failed SQL mutations.
