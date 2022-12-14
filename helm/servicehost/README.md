### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/servicehost
### Install ###
helm upgrade --install servicehost . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall servicehost --namespace mef-dev

