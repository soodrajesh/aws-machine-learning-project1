#!/bin/bash
set -e

# AWS Machine Learning Project Deployment Script
# Region: Ireland (eu-west-1)
# Profile: raj-private

echo "🚀 Starting AWS ML Project Deployment..."

# Configuration
AWS_PROFILE="raj-private"
AWS_REGION="eu-west-1"
PROJECT_NAME="ml-project"
ENVIRONMENT="dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS profile
    if ! aws configure list-profiles | grep -q "$AWS_PROFILE"; then
        print_error "AWS profile '$AWS_PROFILE' not found. Please configure it first."
        exit 1
    fi
    
    print_success "All prerequisites are met!"
}

# Create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f "terraform/terraform.tfvars" ]; then
        print_status "Creating terraform.tfvars from example..."
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        print_warning "Please review and customize terraform/terraform.tfvars before proceeding."
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var-file="terraform.tfvars" -out=tfplan
    
    # Ask for confirmation
    echo
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply changes
        print_status "Applying Terraform changes..."
        terraform apply tfplan
        print_success "Infrastructure deployed successfully!"
    else
        print_warning "Deployment cancelled by user."
        exit 0
    fi
    
    cd ..
}

# Upload sample data to S3
upload_sample_data() {
    print_status "Uploading sample data to S3..."
    
    # Get bucket name from Terraform output
    DATA_BUCKET=$(cd terraform && terraform output -raw data_bucket_name)
    
    if [ -f "data/sample_data.csv" ]; then
        aws s3 cp data/sample_data.csv s3://$DATA_BUCKET/raw/ --profile $AWS_PROFILE
        print_success "Sample data uploaded to s3://$DATA_BUCKET/raw/"
    else
        print_warning "No sample data file found at data/sample_data.csv"
    fi
}

# Create Lambda deployment packages (now handled by Terraform)
create_lambda_packages() {
    print_status "Preparing Lambda deployment packages..."
    
    # Ensure batch inference package directory exists
    mkdir -p scripts/batch_inference_package
    
    # Terraform will handle the actual packaging automatically
    print_success "Lambda package preparation completed!"
}

# Display deployment information
show_deployment_info() {
    print_success "🎉 Deployment completed successfully!"
    echo
    echo "📋 Deployment Information:"
    echo "========================="
    
    cd terraform
    
    echo "🌐 VPC Configuration:"
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "Using existing VPC")
    echo "  VPC ID: $VPC_ID"
    echo "  Region: $AWS_REGION"
    echo "  Profile: $AWS_PROFILE"
    echo
    
    echo "🪣 S3 Buckets:"
    echo "  Data Bucket: $(terraform output -raw data_bucket_name)"
    echo "  Artifacts Bucket: $(terraform output -raw artifacts_bucket_name)"
    echo "  Code Bucket: $(terraform output -raw code_bucket_name)"
    echo
    
    echo "📓 SageMaker:"
    echo "  Notebook Instance: $(terraform output -raw sagemaker_notebook_instance_name)"
    echo "  Notebook URL: $(terraform output -raw sagemaker_notebook_instance_url)"
    echo "  ⚠️  Note: Notebook is in private subnet - access via VPC or start instance to get URL"
    echo
    
    echo "⚡ Lambda Functions:"
    echo "  ML Processor: $(terraform output -raw ml_processor_function_name)"
    echo "  Batch Inference: $(terraform output -raw batch_inference_function_name)"
    echo "  📦 Auto-packaging: Lambda code updates trigger automatic redeployment"
    echo
    
    echo "🔧 Quick Start Commands:"
    echo "  Start SageMaker: aws sagemaker start-notebook-instance --notebook-instance-name $(terraform output -raw sagemaker_notebook_instance_name) --profile $AWS_PROFILE"
    echo "  Check Status: aws sagemaker describe-notebook-instance --notebook-instance-name $(terraform output -raw sagemaker_notebook_instance_name) --profile $AWS_PROFILE"
    echo "  Trigger Training: aws lambda invoke --function-name $(terraform output -raw ml_processor_function_name) --payload '{\"action\":\"train_model\"}' response.json --profile $AWS_PROFILE"
    echo "  Check Artifacts: aws s3 ls s3://$(terraform output -raw artifacts_bucket_name)/models/ --profile $AWS_PROFILE"
    echo
    
    echo "🔒 Security Features:"
    echo "  ✅ VPC Integration with existing infrastructure"
    echo "  ✅ Private subnets for enhanced security"
    echo "  ✅ VPC endpoints for S3 and SageMaker API access"
    echo "  ✅ Security groups with least privilege access"
    echo
    
    echo "💰 Estimated Cost: $0.00 (Free Tier)"
    echo "⚠️  Note: Training jobs may incur small costs if exceeding free tier limits"
    echo "⚠️  VPC endpoints may have minimal data transfer costs"
    
    cd ..
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f terraform/tfplan
    rm -f terraform/lambda_deployment.zip
    rm -f terraform/batch_inference.zip
    rm -rf scripts/batch_inference_package
}

# Main deployment flow
main() {
    echo "🤖 AWS Machine Learning Project Deployment"
    echo "=========================================="
    echo "Region: $AWS_REGION"
    echo "Profile: $AWS_PROFILE"
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo
    
    check_prerequisites
    create_tfvars
    create_lambda_packages
    deploy_infrastructure
    upload_sample_data
    show_deployment_info
    cleanup
    
    print_success "🚀 All done! Your ML pipeline is ready to use!"
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"
