### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/autodoc
### Install ###
helm upgrade --install autodoc . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall autodoc --namespace mef-dev