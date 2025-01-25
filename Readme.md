# Kubernetes Deployment Script

This repository contains an automated deployment script for setting up a production-ready Kubernetes cluster with NGINX, SSL certificates, monitoring, and observability tools.

## 📁 Project Structure

```
.
├── terraform/                # Terraform configuration files
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   └── outputs.tf            # Output definitions
│
├── docker/                   # Docker configuration
│   ├── Dockerfile            # Custom NGINX Dockerfile
│   └── nginx.conf            # NGINX configuration
│
├── scripts/                  # Deployment scripts
│   └── setup.sh              # Combined deployment script
│
└── k8s_yml_samples
│   └── nginx-deployment.yaml # Sample for kubernetes deployment files.(This part automated with scripts/setup.sh)
└── README.md                 # Project documentation
```

## 🚀 Features

- Custom NGINX deployment with high availability
- Automatic SSL certificate management with Let's Encrypt
- Ingress controller configuration
- Complete observability stack:
  - Prometheus metrics collection
  - Grafana visualization
  - Loki log aggregation
- Load balancing
- Resource management and scaling
- Secure HTTPS routing

## 📋 Prerequisites

- Docker installed and configured
- kubectl CLI tool
- Terraform installed
- Access to a Docker registry
- Domain name and DNS configuration
- AWS credentials configured (for EKS)

## 🛠️ Configuration

Before running the script, update the following variables in the script:

```bash
DOMAIN="xyz.xyz"                             # Your domain name
DOCKER_IMAGE="xyz.xyz/custom-nginx:latest"   # Your Docker registry/image
EMAIL="xyz@xyz.xyz"                          # Your email for SSL certificates
```

## 📦 Components

The script sets up the following components:

1. **Custom NGINX Container**
   - Builds and pushes a custom NGINX image
   - Deploys with resource limits and requests
   - Configures high availability with 2 replicas

2. **NGINX Ingress Controller**
   - Manages incoming traffic
   - Handles SSL termination
   - Configures routing rules

3. **SSL Certificates**
   - Automatic SSL certificate management via Let's Encrypt
   - Automatic renewal
   - HTTPS enforcement

4. **Observability Stack**
   - Prometheus for metrics collection
   - Grafana for visualization
   - Loki for log aggregation and querying
   - Accessible via subdirectories:
     - `/prometheus` - Prometheus interface
     - `/grafana` - Grafana dashboard with Loki data sources

## 🚀 Deployment

1. Initialize and apply Terraform configuration:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

2. Run the setup script:
   ```bash
   cd ../scripts
   chmod +x setup.sh
   ./setup.sh
   ```

## 📊 Monitoring and Logging Access

After deployment, you can access the observability tools at:

- Prometheus: `https://your-domain.com/prometheus`
- Grafana: `https://your-domain.com/grafana`
  - Username: `admin`
  - Password: (Generated during deployment)
  - Pre-configured dashboards for:
    - Kubernetes metrics
    - NGINX metrics
    - Log analytics (Loki)

## 🔧 Resource Configuration

### NGINX Deployment
```yaml
resources:
  limits:
    cpu: "500m"
    memory: "256Mi"
  requests:
    cpu: "250m"
    memory: "128Mi"
```

## 🔒 Security Features

- HTTPS enforcement
- Automatic SSL certificate management
- Secure ingress configuration
- Resource isolation
- Monitoring and alerting capabilities

## 📝 Logs and Monitoring

- Centralized log aggregation with Loki
  - Container logs
  - System logs
  - Application logs
- Real-time log querying and exploration
- Log-based alerting capabilities
- Metrics collected by Prometheus
- Visualizations available in Grafana
- Resource usage monitoring
- Performance metrics

## ⚠️ Important Notes

1. Ensure DNS is properly configured for your domain
2. Keep the Grafana password secure
3. Regular monitoring of resource usage is recommended
4. Backup Prometheus and Grafana data as needed
5. Configure log retention policies in Loki as needed

## 🔄 Maintenance

- Monitor resource usage regularly
- Check SSL certificate renewal status
- Update Docker images as needed
- Review Prometheus alerts
- Keep Kubernetes components updated
- Manage log retention and storage

## 🛟 Troubleshooting

If you encounter issues:

1. Check pod status:
   ```bash
   kubectl get pods -A
   ```

2. View pod logs:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```

3. Query logs in Grafana Explore:
   - Select Loki data source
   - Use LogQL to filter and search logs

4. Check ingress status:
   ```bash
   kubectl get ingress -A
   ```

5. Verify SSL certificates:
   ```bash
   kubectl get certificates -A
   ```

- [NGINX Ingress Controller Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
