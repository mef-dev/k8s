### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install api k8s/helm/api/ --values k8s/helm/api/values.yaml --namespace mef-dev --create-namespace
### Uninstall ###
helm uninstall api --namespace mef-dev