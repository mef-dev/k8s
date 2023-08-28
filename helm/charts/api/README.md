### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install api k8s/helm/charts/api/ --values k8s/helm/charts/api/values.yaml --namespace mef-dev --create-namespace
### Uninstall ###
helm uninstall api --namespace mef-dev