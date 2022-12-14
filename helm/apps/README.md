### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/apps
### Install ###
helm upgrade --install apps . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall apps --namespace mef-dev