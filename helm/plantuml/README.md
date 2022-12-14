### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/plantuml
helm upgrade --install plantuml . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall plantuml --namespace mef-dev
