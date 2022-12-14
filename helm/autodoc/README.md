### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/autodoc
helm upgrade --install autodoc . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall autodoc --namespace mef-dev