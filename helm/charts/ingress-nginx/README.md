# Add repo ngress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# Update
helm repo update
# Install
helm install ingress-nginx ingress-nginx/ingress-nginx -f values.yaml --namespace ingress-nginx --create-namespace
