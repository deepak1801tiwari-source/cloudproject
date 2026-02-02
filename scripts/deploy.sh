#!/bin/bash
# scripts/deploy.sh

set -e

echo "🚀 CloudOps Platform Deployment Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    command -v aws >/dev/null 2>&1 || { print_error "AWS CLI is required but not installed."; exit 1; }
    command -v terraform >/dev/null 2>&1 || { print_error "Terraform is required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { print_error "kubectl is required but not installed."; exit 1; }
    command -v docker >/dev/null 2>&1 || { print_error "Docker is required but not installed."; exit 1; }
    
    print_success "All prerequisites installed"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_info "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    terraform init
    terraform validate
    terraform plan -out=tfplan
    terraform apply -auto-approve tfplan
    
    # Get outputs
    terraform output > ../outputs.txt
    
    cd ..
    
    print_success "Infrastructure deployed"
}

# Configure kubectl
configure_kubectl() {
    print_info "Configuring kubectl..."
    
    CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
    
    print_success "kubectl configured"
}

# Initialize database
initialize_database() {
    print_info "Initializing database..."
    
    DB_ENDPOINT=$(terraform -chdir=terraform output -raw rds_endpoint | cut -d':' -f1)
    DB_NAME=$(terraform -chdir=terraform output -raw database_name)
    
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USERNAME" -d "$DB_NAME" -f scripts/init-db.sql
    
    print_success "Database initialized"
}

# Create Kubernetes secrets
create_secrets() {
    print_info "Creating Kubernetes secrets..."
    
    kubectl create namespace cloudops --dry-run=client -o yaml | kubectl apply -f -
    
    # Database secrets
    kubectl create secret generic database-secrets \
        --from-literal=DB_HOST="$(terraform -chdir=terraform output -raw rds_address)" \
        --from-literal=DB_PORT="5432" \
        --from-literal=DB_NAME="$(terraform -chdir=terraform output -raw database_name)" \
        --from-literal=DB_USER="$DB_USERNAME" \
        --from-literal=DB_PASSWORD="$DB_PASSWORD" \
        -n cloudops \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Redis secrets
    kubectl create secret generic redis-secrets \
        --from-literal=REDIS_HOST="$(terraform -chdir=terraform output -raw redis_endpoint)" \
        --from-literal=REDIS_PORT="$(terraform -chdir=terraform output -raw redis_port)" \
        -n cloudops \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # AWS secrets
    kubectl create secret generic aws-secrets \
        --from-literal=S3_BUCKET="$(terraform -chdir=terraform output -raw s3_bucket_name)" \
        --from-literal=SNS_TOPIC_ARN="$(terraform -chdir=terraform output -raw sns_topic_arn)" \
        --from-literal=SQS_QUEUE_URL="$(terraform -chdir=terraform output -raw sqs_queue_url)" \
        -n cloudops \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Secrets created"
}

# Build and push Docker images
build_and_push_images() {
    print_info "Building and pushing Docker images..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
    
    SERVICES=("user-service" "product-service" "cart-service" "order-service")
    
    for SERVICE in "${SERVICES[@]}"; do
        print_info "Building $SERVICE..."
        
        cd "services/$SERVICE"
        docker build -t "$ECR_REGISTRY/$ENVIRONMENT/$SERVICE:latest" .
        docker push "$ECR_REGISTRY/$ENVIRONMENT/$SERVICE:latest"
        cd ../..
        
        print_success "$SERVICE built and pushed"
    done
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    print_info "Deploying to Kubernetes..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Apply namespace and configs
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/configmap.yaml
    
    # Update and apply service manifests
    SERVICES=("user-service" "product-service" "cart-service" "order-service")
    
    for SERVICE in "${SERVICES[@]}"; do
        print_info "Deploying $SERVICE..."
        
        cd "k8s/$SERVICE"
        
        # Update image references
        sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" deployment.yaml
        
        kubectl apply -f serviceaccount.yaml
        kubectl apply -f deployment.yaml
        kubectl apply -f service.yaml
        kubectl apply -f hpa.yaml
        
        # Restore original file
        mv deployment.yaml.bak deployment.yaml
        
        cd ../..
        
        print_success "$SERVICE deployed"
    done
    
    # Apply ingress
    kubectl apply -f k8s/ingress.yaml
    
    print_success "All services deployed"
}

# Install monitoring
install_monitoring() {
    print_info "Installing monitoring stack..."
    
    # Add Helm repos
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring --create-namespace \
        -f monitoring/prometheus-values.yaml
    
    # Install Grafana
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        -f monitoring/grafana-values.yaml
    
    print_success "Monitoring installed"
}

# Main execution
main() {
    print_info "Starting deployment..."
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    create_secrets
    initialize_database
    build_and_push_images
    deploy_to_kubernetes
    install_monitoring
    
    print_success "Deployment complete!"
    
    echo ""
    echo "========================================"
    echo "Access your services:"
    echo "========================================"
    kubectl get ingress -n cloudops
    echo ""
    echo "Grafana admin password:"
    kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
    echo ""
}

# Run main function
main "$@"
