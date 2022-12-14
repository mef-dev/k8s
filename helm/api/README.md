### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/api/
helm upgrade --install api . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall api --namespace mef-dev