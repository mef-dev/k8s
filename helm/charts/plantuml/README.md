### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install plantuml k8s/helm/charts/plantuml/ --values k8s/helm/charts/plantuml/values.yaml --namespace mef-dev --create-namespace
### Uninstall ###
helm uninstall plantuml --namespace mef-dev
