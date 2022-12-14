### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install autodoc k8s/helm/autodoc/ --values k8s/helm/autodoc/values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall autodoc --namespace mef-dev