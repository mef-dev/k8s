### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install servicehost k8s/helm/charts/servicehost/ --values k8s/helm/charts/servicehost/values.yaml --namespace mef-dev --create-namespace
### Uninstall ###
helm uninstall servicehost --namespace mef-dev

