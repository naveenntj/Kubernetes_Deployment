#!/bin/bash

# Define variables
DOMAIN="xyz.xyz"
DOCKER_IMAGE="xyz.xyz/custom-nginx:latest"  # Replace with your Docker registry and image name
EMAIL="xyz@xyz.xyz"                    # Replace with your email for Let's Encrypt notifications

# Change to the terraform directory
cd ../terraform

# Initialize and apply Terraform
terraform init
terraform apply

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube

# Get kubeconfig from terraform output and save it
terraform output -raw kubeconfig > ~/.kube/config

# Set proper permissions
chmod 600 ~/.kube/config

echo "Kubeconfig has been updated. Now waiting for the cluster to become available..."

# Wait for the cluster to become available
echo "Waiting for cluster to become available..."
until kubectl get nodes &>/dev/null; do
    echo "Waiting for cluster nodes to be accessible..."
    sleep 10
done

# Wait for all nodes to be ready
echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

echo "Cluster is now available and ready to use!"

# Build the custom NGINX Docker image
cd ../docker
echo "Building the custom NGINX Docker image..."
docker build -t $DOCKER_IMAGE ./Docker

# Push the Docker image to the registry
echo "Pushing the Docker image to the registry..."
docker push $DOCKER_IMAGE

# Deploy NGINX custom container to Kubernetes
echo "Deploying the custom NGINX container to Kubernetes..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-nginx-deployment
  labels:
    app: custom-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-nginx
  template:
    metadata:
      labels:
        app: custom-nginx
    spec:
      containers:
      - name: custom-nginx
        image: $DOCKER_IMAGE
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "250m"
            memory: "128Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: custom-nginx-service
  labels:
    app: custom-nginx
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: custom-nginx
EOF

# Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for NGINX Ingress Controller to be deployed
echo "Waiting for NGINX Ingress Controller to be deployed..."
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx

# Install Cert-Manager
echo "Installing Cert-Manager..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.10.0/cert-manager.crds.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.10.0/cert-manager.yaml

# Wait for Cert-Manager to be deployed
echo "Waiting for Cert-Manager to be deployed..."
kubectl rollout status deployment/cert-manager -n cert-manager

# Create a ClusterIssuer for Let's Encrypt
echo "Creating ClusterIssuer for Let's Encrypt..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: $EMAIL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Create an Ingress resource for the custom NGINX service
echo "Creating an Ingress resource for domain ${DOMAIN}..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: custom-nginx-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: custom-nginx-service
            port:
              number: 80
  tls:
  - hosts:
    - ${DOMAIN}
    secretName: ${DOMAIN}-tls
EOF

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring

# Install Loki stack (includes Promtail)
echo "Installing Loki and Promtail..."
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

# Install Prometheus and Grafana with Loki datasource
echo "Installing Prometheus and Grafana..."
helm install kube-monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.additionalDataSources[0].name=Loki \
  --set grafana.additionalDataSources[0].type=loki \
  --set grafana.additionalDataSources[0].url=http://loki:3100 \
  --set grafana.additionalDataSources[0].access=proxy

# Wait for deployments
echo "Waiting for Prometheus and Grafana to be deployed..."
kubectl rollout status deployment/kube-monitoring-grafana -n monitoring
kubectl rollout status deployment/kube-monitoring-prometheus -n monitoring
kubectl rollout status statefulset/loki -n monitoring

# NGINX Routes for Grafana and Prometheus
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
spec:
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /grafana(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: kube-monitoring-grafana
            port:
              number: 80
      - path: /prometheus(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: kube-monitoring-prometheus
            port:
              number: 9090
  tls:
  - hosts:
    - ${DOMAIN}
    secretName: ${DOMAIN}-tls
EOF

# Wait for the Ingress to be configured
echo "Waiting for the Ingress resource to be ready..."
kubectl wait --namespace default --for=condition=Ready ingress/custom-nginx-ingress --timeout=90s
kubectl wait --namespace monitoring --for=condition=Ready ingress/monitoring-ingress --timeout=90s

# Get Grafana admin password
echo "Fetching Grafana admin password..."
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring kube-monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana admin password: $GRAFANA_PASSWORD"

# Display instructions
echo "Deployment completed!"
echo "Access your application at https://${DOMAIN}"
echo "Prometheus URL: https://${DOMAIN}/prometheus"
echo "Grafana URL: https://${DOMAIN}/grafana"
echo "Grafana Admin Username: admin"
echo "Grafana Admin Password: $GRAFANA_PASSWORD"
echo ""
echo "Loki has been installed and configured as a Grafana data source."
echo "You can view logs in Grafana by:"
echo "1. Going to Explore"
echo "2. Selecting the Loki data source"
echo "3. Using LogQL to query your logs"