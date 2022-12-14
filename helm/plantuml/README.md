### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install plantuml k8s/helm/plantuml/ --values k8s/helm/plantuml/values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall plantuml --namespace mef-dev
