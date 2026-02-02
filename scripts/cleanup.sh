#!/bin/bash
# scripts/cleanup.sh

set -e

echo "🧹 CloudOps Platform Cleanup Script"
echo "===================================="

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning "This will delete ALL resources created by Terraform!"
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_error "Cleanup cancelled"
    exit 1
fi

# Delete Kubernetes resources
print_warning "Deleting Kubernetes resources..."
kubectl delete namespace cloudops --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

# Destroy Terraform infrastructure
print_warning "Destroying Terraform infrastructure..."
cd terraform
terraform destroy -auto-approve
cd ..

# Delete S3 state bucket (optional)
read -p "Delete Terraform state bucket? (yes/no): " DELETE_BUCKET

if [ "$DELETE_BUCKET" = "yes" ]; then
    aws s3 rb s3://cloudops-terraform-state --force
    aws dynamodb delete-table --table-name terraform-state-lock
fi

echo "✓ Cleanup complete!"
