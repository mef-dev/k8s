### Clone Repository ###
1) git clone https://github.com/mef-dev/k8s.git
2) cd k8s/helm/mssql
### Install ###
helm upgrade --install mssql . --values values.yaml --namespace mef-dev --create-namespace
### Unistall ###
helm uninstall mssql --namespace mef-dev