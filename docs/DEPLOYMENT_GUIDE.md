# AWS Machine Learning Project - Deployment Guide

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with `raj-private` profile
- Terraform >= 1.0
- Python 3.8+
- Git

### 1. Clone and Setup
```bash
git clone <your-repo>
cd aws-machine-learning-project1
```

### 2. Configure AWS Profile
```bash
aws configure --profile raj-private
# Enter your AWS credentials for Ireland region (eu-west-1)
```

### 3. Deploy Infrastructure
```bash
./scripts/deploy.sh
```

This script will:
- ✅ Check prerequisites
- ✅ Create Terraform configuration
- ✅ Deploy AWS infrastructure
- ✅ Upload sample data
- ✅ Display deployment information

## 📋 Manual Deployment Steps

If you prefer manual deployment:

### Step 1: Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### Step 2: Deploy Infrastructure
```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Step 3: Upload Sample Data
```bash
DATA_BUCKET=$(terraform output -raw data_bucket_name)
aws s3 cp ../data/sample_data.csv s3://$DATA_BUCKET/raw/ --profile raj-private
```

## 🔧 Configuration Options

### Terraform Variables
Edit `terraform/terraform.tfvars`:

```hcl
# Project Configuration
project_name = "ml-project"
environment  = "dev"

# AWS Configuration
aws_region  = "eu-west-1"
aws_profile = "raj-private"

# SageMaker Configuration
notebook_instance_type = "ml.t3.medium"  # Free tier
notebook_volume_size   = 20              # GB

# Cost Control
monthly_budget_limit = 10  # USD
```

### Environment Variables
```bash
export AWS_PROFILE=raj-private
export AWS_REGION=eu-west-1
```

## 🎯 Using the ML Pipeline

### 1. Access SageMaker Notebook
1. Go to AWS SageMaker Console (Ireland region)
2. Navigate to "Notebook instances"
3. Open your notebook instance
4. Upload `notebooks/model_training_template.py`
5. Convert to Jupyter notebook and start training!

### 2. Trigger Training via Lambda
```bash
# Get function name
FUNCTION_NAME=$(cd terraform && terraform output -raw ml_processor_function_name)

# Trigger training
aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"action":"train_model"}' \
  response.json \
  --profile raj-private
```

### 3. Check Model Artifacts
```bash
# Get artifacts bucket
ARTIFACTS_BUCKET=$(cd terraform && terraform output -raw artifacts_bucket_name)

# List models
aws s3 ls s3://$ARTIFACTS_BUCKET/models/ --profile raj-private
```

### 4. Batch Inference
```bash
# Upload data for inference
aws s3 cp your_data.csv s3://$DATA_BUCKET/processed/batch_input.csv --profile raj-private

# Trigger batch inference
INFERENCE_FUNCTION=$(cd terraform && terraform output -raw batch_inference_function_name)
aws lambda invoke \
  --function-name $INFERENCE_FUNCTION \
  --payload '{"input_data_key":"processed/batch_input.csv"}' \
  inference_response.json \
  --profile raj-private
```

## 📊 Monitoring

### CloudWatch Metrics
- Navigate to CloudWatch in AWS Console
- Check custom metrics under "ML-Pipeline" namespace
- Monitor Lambda function performance
- Review SageMaker training job logs

### Cost Monitoring
- AWS Cost Explorer
- Budgets and alerts configured automatically
- Free tier usage tracking

## 🛠️ Troubleshooting

### Common Issues

#### SageMaker Notebook Won't Start
```bash
# Check IAM permissions
aws iam get-role --role-name ml-project-dev-sagemaker-execution-role --profile raj-private

# Check notebook status
aws sagemaker describe-notebook-instance \
  --notebook-instance-name ml-project-dev-notebook \
  --profile raj-private
```

#### Lambda Function Errors
```bash
# Check logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/ml-project" --profile raj-private

# View recent logs
aws logs tail /aws/lambda/ml-project-dev-ml-processor --follow --profile raj-private
```

#### S3 Access Issues
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket $DATA_BUCKET --profile raj-private

# Test access
aws s3 ls s3://$DATA_BUCKET --profile raj-private
```

### Performance Optimization

#### Cost Optimization
- Use Spot instances for training (modify Terraform)
- Implement S3 lifecycle policies (already configured)
- Monitor and set up billing alerts

#### Training Optimization
- Use larger instance types for complex models
- Implement distributed training for large datasets
- Use SageMaker Processing for data preprocessing

## 🧹 Cleanup

### Destroy Infrastructure
```bash
cd terraform
terraform destroy -var-file="terraform.tfvars"
```

### Manual Cleanup
If Terraform destroy fails:
```bash
# Delete S3 objects first
aws s3 rm s3://$DATA_BUCKET --recursive --profile raj-private
aws s3 rm s3://$ARTIFACTS_BUCKET --recursive --profile raj-private

# Then destroy infrastructure
terraform destroy -var-file="terraform.tfvars"
```

## 📈 Scaling Up

### Production Considerations
1. **Security**: Implement VPC, private subnets, and endpoint security
2. **Monitoring**: Add comprehensive logging and alerting
3. **CI/CD**: Implement automated model deployment pipeline
4. **Data Pipeline**: Add data validation and quality checks
5. **Model Management**: Implement model versioning and A/B testing

### Advanced Features
- Multi-region deployment
- Auto-scaling for inference endpoints
- Real-time model monitoring
- Automated retraining pipelines
- Integration with MLOps tools

## 🆘 Support

### Documentation
- [AWS SageMaker Documentation](https://docs.aws.amazon.com/sagemaker/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)

### Getting Help
1. Check CloudWatch logs for detailed error messages
2. Review AWS service quotas and limits
3. Verify IAM permissions and policies
4. Test with minimal configurations first

---

**Built with ❤️ for cost-effective ML on AWS**
