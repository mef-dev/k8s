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

helm install app

```
mkdir -p /mefdev/mssql-data /mefdev/mefdev-storage /mefdev/apps-storage
git clone https://github.com/mef-dev/k8s.git
kubectl create namespace mef-dev
helm upgrade --install mssql k8s/helm/charts/mssql/ --values k8s/helm/charts/mssql/values.yaml --namespace mef-dev
helm upgrade --install apps k8s/helm/charts/apps/ --values k8s/helm/charts/apps/values.yaml --namespace mef-dev
helm upgrade --install api k8s/helm/charts/api/ --values k8s/helm/charts/api/values.yaml --namespace mef-dev
helm upgrade --install autodoc k8s/helm/charts/autodoc/ --values k8s/helm/charts/autodoc/values.yaml --namespace mef-dev
helm upgrade --install servicehost k8s/helm/charts/servicehost/ --values k8s/helm/charts/servicehost/values.yaml --namespace mef-dev
helm upgrade --install plantuml k8s/helm/charts/plantuml/ --values k8s/helm/charts/plantuml/values.yaml --namespace mef-dev
```

#### List the Created Objects
```
$ kubectl get all --namespace mef-dev
NAME                                    READY   STATUS    RESTARTS   AGE
pod/mssql-0                             1/1     Running   0          7m39s
pod/apps-7cfd95c584-gg7d4               1/1     Running   0          5m29s
pod/api-668f59687d-7rvxn                1/1     Running   0          5m22s
pod/autodoc-6f7d6cfdb9-9b5nr            1/1     Running   0          5m16s
pod/servicehost-6d85d848b-7txdw         1/1     Running   0          5m9s
pod/plantuml-plantuml-544cd6544b-w2pb6  1/1     Running   0          5m2s

NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)          AGE
service/mssql              LoadBalancer   10.43.213.10    192.168.50.12   1433:32091/TCP   7m39s
service/apps               LoadBalancer   10.43.14.151    192.168.50.12   81:30188/TCP     5m29s
service/api                LoadBalancer   10.43.12.43     192.168.50.12   82:30753/TCP     5m22s
service/autodoc            LoadBalancer   10.43.120.168   192.168.50.12   83:30488/TCP     5m16s
service/servicehost        LoadBalancer   10.43.7.94      192.168.50.12   84:32274/TCP     5m9s
service/plantuml-plantuml  LoadBalancer   10.43.152.190   192.168.50.12   85:31176/TCP     5m2s
```


### After running the pod, you can use the following ports
1) http://$SERVICE_IP:81
The APP is web frontend (GUI) element of serverless MEF.DEV openAPI platform.
2) http://$SERVICE_IP:82
The API is a backend stateless element of serverless MEF.DEV openAPI platform.
3) http://$SERVICE_IP:83
The AUTODOC is a backend statefull element of serverless MEF.DEV openAPI platform.
4) http://$SERVICE_IP:84
The SERVICEHOST is a backend statefull element of serverless MEF.DEV openAPI platform.
5) http://$SERVICE_IP:85
PlantUML is an open-source tool allowing users to create diagrams from a plain text language.
6) mssql - $SERVICE_IP:1433

### Helm uninstall app
```
helm uninstall apps --namespace mef-dev
helm uninstall api --namespace mef-dev
helm uninstall autodoc --namespace mef-dev
helm uninstall servicehost --namespace mef-dev
helm uninstall plantuml --namespace mef-dev
helm uninstall mssql --namespace mef-dev
rm -fr /mefdev/
kubectl delete namespace mef-dev
```
