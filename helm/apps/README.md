### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install apps k8s/helm/apps/ --values k8s/helm/apps/values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall apps --namespace mef-dev