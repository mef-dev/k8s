### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/servicehost
helm upgrade --install servicehost . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall servicehost --namespace mef-dev

