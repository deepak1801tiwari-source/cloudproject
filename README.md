# CloudOps Platform

A complete enterprise-grade cloud-native microservices platform built with modern DevOps practices.

## 🏗️ Architecture

This platform consists of:
- **4 Microservices**: User, Product, Cart, Order services
- **Infrastructure as Code**: Terraform for AWS resources
- **Container Orchestration**: Kubernetes (EKS)
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus & Grafana
- **Databases**: PostgreSQL (RDS), Redis (ElastiCache)

## 📋 Prerequisites

- AWS Account with credentials configured
- Tools installed:
  - AWS CLI
  - Terraform >= 1.6.0
  - kubectl
  - Docker
  - Helm

## 🚀 Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/cloudops-platform.git
cd cloudops-platform
```

### 2. Configure environment variables
```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
export DB_USERNAME=your_db_username
export DB_PASSWORD=your_strong_password
```

### 3. Deploy everything
```bash
./scripts/deploy.sh
```

## 📖 Manual Deployment Steps

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 2: Configure kubectl
```bash
aws eks update-kubeconfig --name dev-eks-cluster --region us-east-1
```

### Step 3: Initialize Database
```bash
# Get RDS endpoint from Terraform output
DB_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d':' -f1)

# Run initialization script
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USERNAME" -d cloudops_db -f ../scripts/init-db.sql
```

### Step 4: Create Kubernetes Secrets
```bash
kubectl create namespace cloudops

kubectl create secret generic database-secrets \
  --from-literal=DB_HOST="$(terraform output -raw rds_address)" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_NAME="cloudops_db" \
  --from-literal=DB_USER="$DB_USERNAME" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  -n cloudops
```

### Step 5: Build and Push Docker Images
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Build and push each service
cd services/user-service
docker build -t "$ECR_REGISTRY/dev/user-service:latest" .
docker push "$ECR_REGISTRY/dev/user-service:latest"
```

### Step 6: Deploy to Kubernetes
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/user-service/
kubectl apply -f k8s/product-service/
kubectl apply -f k8s/cart-service/
kubectl apply -f k8s/order-service/
kubectl apply -f k8s/ingress.yaml
```

### Step 7: Install Monitoring
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus -n monitoring --create-namespace
helm install grafana grafana/grafana -n monitoring
```

## 🧪 Testing

### Test User Service
```bash
INGRESS_URL=$(kubectl get ingress api-ingress -n cloudops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$INGRESS_URL/api/users/health
```

### Test Product Service
```bash
curl http://$INGRESS_URL/api/products
```

## 📊 Accessing Monitoring

### Grafana
```bash
# Get Grafana password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access locally
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Visit: http://localhost:3000
- Username: `admin`
- Password: (from command above)

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

Visit: http://localhost:9090

## 🔍 Troubleshooting

### Check pod status
```bash
kubectl get pods -n cloudops
kubectl logs -f deployment/user-service -n cloudops
```

### Check service endpoints
```bash
kubectl get svc -n cloudops
kubectl get ingress -n cloudops
```

### Database connection issues
```bash
kubectl exec -it deployment/user-service -n cloudops -- sh
# Inside container:
nc -zv $DB_HOST 5432
```

## 🧹 Cleanup

To delete all resources:
```bash
./scripts/cleanup.sh
```

Or manually:
```bash
kubectl delete namespace cloudops
kubectl delete namespace monitoring
cd terraform
terraform destroy
```

## 📁 Project Structure
```
cloudops-platform/
├── services/           # Microservices source code
│   ├── user-service/
│   ├── product-service/
│   ├── cart-service/
│   └── order-service/
├── terraform/          # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   └── rds/
│   └── main.tf
├── k8s/               # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── user-service/
│   ├── product-service/
│   ├── cart-service/
│   └── order-service/
├── .github/workflows/  # CI/CD pipelines
├── monitoring/        # Monitoring configs
├── scripts/          # Deployment scripts
└── docs/            # Documentation
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License

## 👥 Authors

Your Name - [deepak1801tiwari@gmail.com](deepak1801tiwari@gmail.com)

## 🙏 Acknowledgments

- AWS for cloud infrastructure
- Kubernetes community
- Terraform by HashiCorp
