### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install apps k8s/helm/charts/apps/ --values k8s/helm/charts/apps/values.yaml --namespace mef-dev --create-namespace
### Uninstall  ###
helm uninstall apps --namespace mef-dev