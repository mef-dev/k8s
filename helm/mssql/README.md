### Clone Repository ###
git clone https://github.com/mef-dev/k8s.git
### Install ###
cd k8s/helm/mssql
helm upgrade --install mssql . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall mssql --namespace mef-dev