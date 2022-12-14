### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/apps
helm upgrade --install apps . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall apps --namespace mef-dev