### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/api/
### Install ###
helm upgrade --install api . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall api --namespace mef-dev