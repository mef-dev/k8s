# Gateway and Ingress variants

| Directory | API / controller |
|---|---|
| `gateway/nginx-gateway-fabric/` | Gateway API, NGINX Gateway Fabric |
| `gateway/envoy-gateway/` | Gateway API, Envoy Gateway |
| `gateway/traefik/` | Gateway API, Traefik |
| `gateway/common/` | Shared Gateway API settings such as CORS |
| `classic/traefik/` | Ingress API, Traefik |
| `classic/ingress-nginx/` | Ingress API, community ingress-nginx (legacy) |
| `classic/haproxy/` | Ingress API, HAProxy |

Select one variant for each application. Merge `api.yaml`, `apps.yaml`,
`servicehost.yaml`, `knowledge-graph.yaml` or `plantuml.yaml` into the matching complete
`helm/values/<component>.yaml`, set your domains, then upgrade using that single
values file. Gateway and Ingress modes are mutually exclusive.

`controller-values.yaml` is for installing the controller with Helm, not for an
application chart. `controller-local.yaml` contains optional laptop settings.
Files with top-level `apiVersion` and `kind` are Kubernetes manifests (Gateway,
GatewayClass, redirect routes, controller policies or Middleware); apply only the
selected manifests after installing the required controller/CRDs and TLS Secret.
Do not apply this entire directory as Kubernetes manifests or pass it all to Helm.

[Installation and networking instructions](../../../README.md#networking).
The classic profiles assume an existing controller with the matching ingress class.
