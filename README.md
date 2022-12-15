# Overview
The Serverless MEF.DEV platform provides accelerated development, hosting, and application management capabilities for independent developers and teams based on the IoC Container Composition through an agile development process based on continuous integration principles. It has a user-friendly interface that simplifies the process of developing integration applications with a good level of service agreement and based on enterprise-approved standards for authorization, authentication, managed deployment with standardized approaches to monitoring and SOX controls.

# Helm Chart Templates for mef-dev apps in Kubernetes
This project provides template Helm Charts for deploying a mef-dev application into any Kubernetes based cloud.
## Prerequisites
Using the template Helm charts assumes the following pre-requisites are complete:  

1. You have a Kubernetes cluster  
  This could be one hosted by a cloud provider or running locally, for example using [k3s](https://k3s.io/)
  
2. You have kubectl installed and configured for your cluster  
  The [Kuberenetes command line](https://kubernetes.io/docs/tasks/tools/install-kubectl/) tool, `kubectl`, is used to view and control your Kubernetes cluster.

3. You have the Helm command line installed  
   [Helm](https://docs.helm.sh/using_helm/) provide the command line tool for deploying your application using the Helm chart.
   These charts are compatible with Helm v3


### Deploy applications mef-dev with helm in Kubernetes

add repo mef-dev
```
helm repo add mef-dev https://raw.githubusercontent.com/mef-dev/k8s/dev
```
helm install app
```
helm install mssql mef-dev/mssql --namespace mef-dev
helm install apps mef-dev/apps --namespace mef-dev
helm install api mef-dev/api --namespace mef-dev
helm install autodoc mef-dev/autodoc --namespace mef-dev
helm install servicehost mef-dev/servicehost --namespace mef-dev
helm install platuml mef-dev/plantuml --namespace mef-dev
```
Or
```
git clone https://github.com/mef-dev/k8s.git
kubectl create namespace mef-dev
helm upgrade --install mssql k8s/helm/charts/mssql/ --values k8s/helm/charts/mssql/values.yaml --namespace mef-dev
helm upgrade --install apps k8s/helm/charts/apps/ --values k8s/helm/charts/apps/values.yaml --namespace mef-dev
helm upgrade --install api k8s/helm/charts/api/ --values k8s/helm/charts/api/values.yaml --namespace mef-dev
helm upgrade --install autodoc k8s/helm/charts/autodoc/ --values k8s/helm/charts/autodoc/values.yaml --namespace mef-dev
helm upgrade --install servicehost k8s/helm/charts/servicehost/ --values k8s/helm/charts/servicehost/values.yaml --namespace mef-dev
helm upgrade --install plantuml k8s/helm/charts/plantuml/ --values k8s/helm/charts/plantuml/values.yaml --namespace mef-dev
```

### Helm uninstall app
```
helm uninstall apps --namespace mef-dev
helm uninstall api --namespace mef-dev
helm uninstall autodoc --namespace mef-dev
helm uninstall servicehost --namespace mef-dev
helm uninstall plantuml --namespace mef-dev
helm uninstall mssql --namespace mef-dev
sudo rm -fr /mefdev/
kubectl delete namespace mef-dev
```
