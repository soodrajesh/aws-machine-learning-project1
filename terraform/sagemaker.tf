# SageMaker Resources for ML Project

# SageMaker Notebook Instance
resource "aws_sagemaker_notebook_instance" "ml_notebook" {
  name                    = "${local.name_prefix}-notebook"
  role_arn               = aws_iam_role.sagemaker_execution_role.arn
  instance_type          = var.notebook_instance_type
  platform_identifier    = "notebook-al2-v2"
  volume_size            = var.notebook_volume_size
  
  # Use existing VPC configuration
  subnet_id              = local.subnet_ids[0]
  security_groups        = [aws_security_group.sagemaker_sg.id]
  direct_internet_access = "Disabled"  # Use VPC endpoints for security

  # Default code repository (optional)
  default_code_repository = aws_sagemaker_code_repository.ml_code_repo.code_repository_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-notebook"
    Purpose = "ML Development and Training"
  })

  depends_on = [
    aws_iam_role.sagemaker_execution_role,
    aws_security_group.sagemaker_sg,
    aws_sagemaker_code_repository.ml_code_repo
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to the notebook instance state
      # as it can be stopped/started manually
    ]
  }
}

# SageMaker Code Repository
resource "aws_sagemaker_code_repository" "ml_code_repo" {
  code_repository_name = "${local.name_prefix}-code-repo"

  git_config {
    repository_url = "https://github.com/aws/amazon-sagemaker-examples.git"
    branch         = "main"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-code-repo"
    Purpose = "SageMaker Code Repository"
  })
}

# CloudWatch Log Group for SageMaker
resource "aws_cloudwatch_log_group" "sagemaker_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/sagemaker/NotebookInstances/${local.name_prefix}-notebook"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sagemaker-logs"
    Purpose = "SageMaker Logging"
  })
}

# CloudWatch Log Group for Training Jobs
resource "aws_cloudwatch_log_group" "training_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/sagemaker/TrainingJobs"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-training-logs"
    Purpose = "SageMaker Training Job Logging"
  })
}

# SageMaker Model (placeholder - will be created by training job)
resource "aws_sagemaker_model" "ml_model" {
  count            = 0 # Created dynamically by training jobs
  name             = "${local.name_prefix}-model"
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image = "683313688378.dkr.ecr.${local.region}.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3"
    model_data_url = "s3://${aws_s3_bucket.artifacts_bucket.bucket}/models/model.tar.gz"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-model"
    Purpose = "Trained ML Model"
  })
}

# SageMaker Endpoint Configuration (placeholder)
resource "aws_sagemaker_endpoint_configuration" "ml_endpoint_config" {
  count = 0 # Created when model is ready
  name  = "${local.name_prefix}-endpoint-config"

  production_variants {
    variant_name           = "primary"
    model_name            = aws_sagemaker_model.ml_model[0].name
    initial_instance_count = 1
    instance_type         = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-endpoint-config"
    Purpose = "ML Model Endpoint Configuration"
  })
}

# SageMaker Endpoint (placeholder)
resource "aws_sagemaker_endpoint" "ml_endpoint" {
  count                = 0 # Created when needed
  name                 = "${local.name_prefix}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.ml_endpoint_config[0].name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-endpoint"
    Purpose = "ML Model Inference Endpoint"
  })
}

# Data sources for existing VPC and route tables
data "aws_route_tables" "private" {
  vpc_id = local.vpc_id
  
  filter {
    name   = "tag:Name"
    values = ["*private*", "*Private*"]
  }
}

# SageMaker Domain (for SageMaker Studio - optional)
resource "aws_sagemaker_domain" "ml_domain" {
  count       = 0 # Disabled for cost optimization - use notebook instance instead
  domain_name = "${local.name_prefix}-domain"
  auth_mode   = "IAM"
  vpc_id      = local.vpc_id
  subnet_ids  = local.subnet_ids

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn
    
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type       = "ml.t3.medium"
        sagemaker_image_arn = "arn:aws:sagemaker:${local.region}:683313688378:image/datascience-1.0"
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = "ml.t3.medium"
        sagemaker_image_arn = "arn:aws:sagemaker:${local.region}:683313688378:image/datascience-1.0"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-domain"
    Purpose = "SageMaker Studio Domain"
  })
}

# Security Group for SageMaker
resource "aws_security_group" "sagemaker_sg" {
  name_prefix = "${local.name_prefix}-sagemaker-sg"
  vpc_id      = local.vpc_id
  description = "Security group for SageMaker notebook instance"

  # Allow HTTPS outbound for package downloads and API calls
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP outbound for package downloads
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Git SSH access
  egress {
    description = "SSH outbound for Git"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sagemaker-sg"
    Purpose = "SageMaker Security Group"
  })
}

# VPC Endpoints for SageMaker (cost-optimized)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
    Purpose = "S3 VPC Endpoint"
  })
}

resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${local.region}.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sagemaker-api-endpoint"
    Purpose = "SageMaker API VPC Endpoint"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name_prefix = "${local.name_prefix}-vpc-endpoint-sg"
  vpc_id      = local.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.has_existing_vpc ? data.aws_vpc.existing[0].cidr_block : data.aws_vpc.default.cidr_block]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoint-sg"
    Purpose = "VPC Endpoint Security Group"
  })
}

# CloudWatch Alarms for SageMaker Monitoring
resource "aws_cloudwatch_metric_alarm" "notebook_cpu_utilization" {
  alarm_name          = "${local.name_prefix}-notebook-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/SageMaker"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors SageMaker notebook CPU utilization"
  alarm_actions       = []

  dimensions = {
    NotebookInstanceName = aws_sagemaker_notebook_instance.ml_notebook.name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cpu-alarm"
    Purpose = "SageMaker Monitoring"
  })
}
