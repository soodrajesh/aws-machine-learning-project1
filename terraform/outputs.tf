# Terraform Outputs for AWS Machine Learning Project

# S3 Bucket Outputs
output "data_bucket_name" {
  description = "Name of the S3 bucket for data storage"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "data_bucket_arn" {
  description = "ARN of the S3 bucket for data storage"
  value       = aws_s3_bucket.data_bucket.arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for model artifacts"
  value       = aws_s3_bucket.artifacts_bucket.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for model artifacts"
  value       = aws_s3_bucket.artifacts_bucket.arn
}

output "code_bucket_name" {
  description = "Name of the S3 bucket for code storage"
  value       = aws_s3_bucket.code_bucket.bucket
}

output "code_bucket_arn" {
  description = "ARN of the S3 bucket for code storage"
  value       = aws_s3_bucket.code_bucket.arn
}

# SageMaker Outputs
output "sagemaker_notebook_instance_name" {
  description = "Name of the SageMaker notebook instance"
  value       = aws_sagemaker_notebook_instance.ml_notebook.name
}

output "sagemaker_notebook_instance_url" {
  description = "URL of the SageMaker notebook instance"
  value       = aws_sagemaker_notebook_instance.ml_notebook.url
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "sagemaker_code_repository_name" {
  description = "Name of the SageMaker code repository"
  value       = aws_sagemaker_code_repository.ml_code_repo.code_repository_name
}

# Lambda Outputs
output "ml_processor_function_name" {
  description = "Name of the ML processor Lambda function"
  value       = aws_lambda_function.ml_processor.function_name
}

output "ml_processor_function_arn" {
  description = "ARN of the ML processor Lambda function"
  value       = aws_lambda_function.ml_processor.arn
}

output "batch_inference_function_name" {
  description = "Name of the batch inference Lambda function"
  value       = aws_lambda_function.batch_inference.function_name
}

output "batch_inference_function_arn" {
  description = "ARN of the batch inference Lambda function"
  value       = aws_lambda_function.batch_inference.arn
}

# IAM Role Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "cloudwatch_events_role_arn" {
  description = "ARN of the CloudWatch Events role"
  value       = aws_iam_role.cloudwatch_events_role.arn
}

# CloudWatch Outputs
output "sagemaker_log_group_name" {
  description = "Name of the SageMaker CloudWatch log group"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.sagemaker_logs[0].name : null
}

output "training_log_group_name" {
  description = "Name of the training jobs CloudWatch log group"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.training_logs[0].name : null
}

output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

# CloudWatch Event Outputs
output "scheduled_training_rule_name" {
  description = "Name of the scheduled training CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.scheduled_training.name
}

output "scheduled_training_rule_arn" {
  description = "ARN of the scheduled training CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.scheduled_training.arn
}

# Project Information
output "project_name" {
  description = "Name of the ML project"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = local.account_id
}

# Quick Start Commands
output "quick_start_commands" {
  description = "Quick start commands for using the ML pipeline"
  value = {
    upload_data = "aws s3 cp your-data.csv s3://${aws_s3_bucket.data_bucket.bucket}/raw/ --profile ${var.aws_profile}"
    open_notebook = "Open SageMaker console and navigate to ${aws_sagemaker_notebook_instance.ml_notebook.name}"
    trigger_training = "aws lambda invoke --function-name ${aws_lambda_function.ml_processor.function_name} --payload '{\"action\":\"train_model\"}' response.json --profile ${var.aws_profile}"
    check_artifacts = "aws s3 ls s3://${aws_s3_bucket.artifacts_bucket.bucket}/models/ --profile ${var.aws_profile}"
  }
}

# Cost Monitoring
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    sagemaker_notebook = "Free tier: 250 hours ml.t3.medium"
    s3_storage = "Free tier: 5GB storage"
    lambda_requests = "Free tier: 1M requests"
    cloudwatch_logs = "Free tier: 5GB ingestion"
    total_free_tier = "$0.00"
    note = "Costs may apply for training jobs exceeding free tier limits"
  }
}
