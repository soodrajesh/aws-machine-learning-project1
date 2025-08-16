# Terraform Variables for AWS Machine Learning Project

variable "project_name" {
  description = "Name of the ML project"
  type        = string
  default     = "ml-project"
  
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 20
    error_message = "Project name must be between 1 and 20 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in format like eu-west-1."
  }
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "raj-private"
}

# SageMaker Configuration
variable "notebook_instance_type" {
  description = "SageMaker notebook instance type"
  type        = string
  default     = "ml.t3.medium"
  
  validation {
    condition = contains([
      "ml.t2.medium", "ml.t3.medium", "ml.t3.large",
      "ml.m5.large", "ml.m5.xlarge"
    ], var.notebook_instance_type)
    error_message = "Instance type must be a valid SageMaker instance type."
  }
}

variable "notebook_volume_size" {
  description = "Size of the EBS volume for SageMaker notebook (GB)"
  type        = number
  default     = 20
  
  validation {
    condition     = var.notebook_volume_size >= 5 && var.notebook_volume_size <= 100
    error_message = "Volume size must be between 5 and 100 GB."
  }
}

# S3 Configuration
variable "s3_versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_encryption_enabled" {
  description = "Enable S3 bucket encryption"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.lambda_timeout >= 30 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 30 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 3008
    error_message = "Lambda memory size must be between 128 and 3008 MB."
  }
}

# Training Configuration
variable "training_instance_type" {
  description = "SageMaker training instance type"
  type        = string
  default     = "ml.m5.large"
  
  validation {
    condition = contains([
      "ml.m5.large", "ml.m5.xlarge", "ml.m5.2xlarge",
      "ml.c5.xlarge", "ml.c5.2xlarge"
    ], var.training_instance_type)
    error_message = "Training instance type must be a valid SageMaker training instance."
  }
}

variable "max_training_time" {
  description = "Maximum training time in seconds"
  type        = number
  default     = 3600
  
  validation {
    condition     = var.max_training_time >= 600 && var.max_training_time <= 86400
    error_message = "Training time must be between 600 and 86400 seconds (10 min to 24 hours)."
  }
}

# Monitoring Configuration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Cost Control
variable "enable_cost_alerts" {
  description = "Enable cost monitoring alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 10
  
  validation {
    condition     = var.monthly_budget_limit > 0 && var.monthly_budget_limit <= 100
    error_message = "Budget limit must be between 1 and 100 USD."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
