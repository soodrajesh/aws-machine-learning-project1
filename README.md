# AWS Machine Learning Project 🤖

A complete AWS-based machine learning pipeline using Infrastructure as Code (Terraform) with SageMaker, S3, and automated batch processing.

## 🏗️ Architecture

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Raw    │───▶│  SageMaker       │───▶│  Training Job   │───▶│  S3 Artifacts   │
│   Data      │    │  Notebook        │    │                 │    │                 │
└─────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
                            │                        ▲
                            ▼                        │
                   ┌─────────────────┐    ┌─────────────────┐
                   │  Lambda Batch   │    │  CloudWatch     │
                   │  Processing     │    │  Events         │
                   └─────────────────┘    └─────────────────┘
```

## 🎯 Features

- **Cost-Optimized**: Uses AWS free tier resources ($0.00 monthly cost)
- **Infrastructure as Code**: Complete Terraform setup with 46+ resources
- **VPC Integration**: Automatic detection of existing VPC with fallback to default
- **Automated Pipeline**: Lambda-triggered batch processing with auto-packaging
- **Sample Data**: Pre-loaded datasets for quick start
- **Model Artifacts**: Automated S3 storage with lifecycle policies
- **Monitoring**: CloudWatch integration with custom metrics
- **Security**: IAM roles with least privilege and VPC endpoints
- **Production Ready**: Proper resource dependencies and error handling

## 📁 Project Structure

```
aws-machine-learning-project1/
├── terraform/              # Infrastructure as Code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   ├── s3.tf              # S3 buckets configuration
│   ├── sagemaker.tf       # SageMaker resources
│   ├── iam.tf             # IAM roles and policies
│   └── lambda.tf          # Lambda functions
├── notebooks/             # Jupyter notebooks
│   ├── data_exploration.ipynb
│   ├── model_training.ipynb
│   └── model_evaluation.ipynb
├── scripts/               # Python scripts
│   ├── data_preprocessing.py
│   ├── train_model.py
│   ├── batch_inference.py
│   └── lambda_handler.py
├── data/                  # Sample datasets
│   ├── raw/
│   └── processed/
├── models/                # Trained model artifacts
└── docs/                  # Documentation
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with `raj-private` profile
- Terraform >= 1.0
- Python 3.9+
- Git

### Automated Deployment

```bash
# Clone the repository
git clone <repository-url>
cd aws-machine-learning-project1

# Initialize and validate Terraform
cd terraform
terraform init
terraform validate

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Plan and apply infrastructure
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Or use automated deployment script
./scripts/deploy.sh
```

### 2. Upload Sample Data

```bash
aws s3 cp data/raw/ s3://ml-project-data-bucket-<random-id>/raw/ --recursive --profile raj-private
```

## 💰 Cost Estimation

**Monthly Cost: $0.00** (AWS Free Tier)

- **SageMaker Notebook**: 250 hours/month (ml.t3.medium)
- **Lambda Functions**: 1M requests/month + 400,000 GB-seconds
- **S3 Storage**: 5GB with lifecycle policies (IA after 30 days, Glacier after 90 days)
- **CloudWatch**: 5GB log ingestion + custom metrics
- **VPC Endpoints**: Gateway endpoints for S3 (no charge)
- **Data Transfer**: Within same AZ (no charge)

*Note: Costs may apply if you exceed free tier limits or run extensive training jobs.*

## 📊 Sample Use Cases

1. **Customer Churn Prediction** (Classification)
2. **House Price Prediction** (Regression)
3. **Sales Forecasting** (Time Series)
4. **Sentiment Analysis** (NLP)

## 🔒 Security

- IAM roles with least privilege access
- S3 bucket encryption enabled
- VPC endpoints for secure communication
- CloudTrail logging enabled

## 📈 Monitoring

- CloudWatch metrics for all services
- Custom metrics for model performance
- Automated alerts for failures
- Cost monitoring and budgets

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

1. **SageMaker notebook won't start**: Check IAM permissions
2. **S3 access denied**: Verify bucket policies
3. **Lambda timeout**: Increase timeout in Terraform config
4. **High costs**: Monitor usage in AWS Cost Explorer

### Support

- Check AWS documentation
- Review CloudWatch logs
- Open GitHub issues for bugs

---

**Built with ❤️ using AWS, Terraform, and Python**
