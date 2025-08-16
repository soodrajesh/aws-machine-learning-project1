# Terraform Variables Example File
# Copy this file to terraform.tfvars and customize the values

# Project Configuration
project_name = "ml-project"
environment  = "dev"

# AWS Configuration
aws_region  = "eu-west-1"
aws_profile = "raj-private"

# SageMaker Configuration
notebook_instance_type = "ml.t3.medium"  # Free tier eligible
notebook_volume_size   = 20              # GB

# S3 Configuration
s3_versioning_enabled = true
s3_encryption_enabled = true

# Lambda Configuration
lambda_timeout     = 300  # 5 minutes
lambda_memory_size = 512  # MB

# Training Configuration
training_instance_type = "ml.m5.large"
max_training_time     = 3600  # 1 hour

# Monitoring Configuration
enable_cloudwatch_logs = true
log_retention_days     = 14

# Cost Control
enable_cost_alerts   = true
monthly_budget_limit = 10  # USD

# Additional Tags (optional)
additional_tags = {
  Owner       = "DataScience Team"
  CostCenter  = "ML-Research"
  Environment = "Development"
}
