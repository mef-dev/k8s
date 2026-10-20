# Kubernetes Secrets

Copy the five YAML templates to `.local/secrets/`, replace every `REPLACE_*` marker,
and apply them before installing the applications:

```bash
kubectl --context "$KUBE_CONTEXT" --namespace mef-dev apply -f .local/secrets/
```

Set the cluster and namespace using [installation](../../../README.md#1-prepare-the-repository-and-namespace).
Secrets are plain YAML without SOPS. Templates omit namespace; `--namespace mef-dev` selects it.
Keep database passwords consistent with the application connection strings and do not
commit filled Secrets. Changing a Secret alone does not rotate database credentials.

`api-secrets/entraClientSecret` is required for the primary Microsoft sign-in; fill
it with the client secret Value from your own App Registration. See
[Microsoft Entra ID](../../../README.md#microsoft-entra-id).
