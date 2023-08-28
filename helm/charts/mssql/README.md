### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
helm upgrade --install mssql k8s/helm/charts/mssql/ --values k8s/helm/charts/mssql/values.yaml --namespace mef-dev --create-namespace
### Uninstall ###
helm uninstall mssql --namespace mef-dev