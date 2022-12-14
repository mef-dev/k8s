### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/plantuml
### Install ###
helm upgrade --install plantuml . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall plantuml --namespace mef-dev
