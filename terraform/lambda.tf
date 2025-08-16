# Lambda Functions for ML Pipeline Automation

# Create Lambda deployment package for ML processor
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_deployment.zip"
  
  source {
    content  = file("${path.module}/../scripts/lambda_handler.py")
    filename = "lambda_handler.py"
  }
}

# Lambda function for ML processing
resource "aws_lambda_function" "ml_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-ml-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # VPC Configuration for existing VPC
  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DATA_BUCKET      = aws_s3_bucket.data_bucket.bucket
      ARTIFACTS_BUCKET = aws_s3_bucket.artifacts_bucket.bucket
      CODE_BUCKET      = aws_s3_bucket.code_bucket.bucket
      SAGEMAKER_ROLE   = aws_iam_role.sagemaker_execution_role.arn
      TRAINING_INSTANCE_TYPE = var.training_instance_type
      MAX_TRAINING_TIME = var.max_training_time
      AWS_REGION       = var.aws_region
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ml-processor"
    Purpose = "ML Pipeline Automation"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs,
    aws_security_group.lambda_sg,
    data.archive_file.lambda_zip
  ]
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ml_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
  
  depends_on = [aws_lambda_function.ml_processor]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}-ml-processor"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-logs"
    Purpose = "Lambda Function Logging"
  })
}

# CloudWatch Event Rule for scheduled training
resource "aws_cloudwatch_event_rule" "scheduled_training" {
  name                = "${local.name_prefix}-scheduled-training"
  description         = "Trigger ML training on schedule"
  schedule_expression = "cron(0 2 * * ? *)" # Daily at 2 AM UTC

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-scheduled-training"
    Purpose = "Scheduled ML Training"
  })
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.scheduled_training.name
  target_id = "TriggerLambdaFunction"
  arn       = aws_lambda_function.ml_processor.arn

  input = jsonencode({
    "trigger_type" = "scheduled"
    "action" = "train_model"
  })
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ml_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_training.arn
}

# Create batch inference Lambda deployment package
data "archive_file" "batch_inference_zip" {
  type        = "zip"
  output_path = "${path.module}/batch_inference.zip"
  
  source_dir = "${path.module}/../scripts/batch_inference_package"
  
  depends_on = [local_file.batch_inference_package]
}

# Create batch inference package directory with dependencies
resource "local_file" "batch_inference_package" {
  content = file("${path.module}/../scripts/batch_inference.py")
  filename = "${path.module}/../scripts/batch_inference_package/batch_inference.py"
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/../scripts/batch_inference_package
      cp ${path.module}/../scripts/batch_inference.py ${path.module}/../scripts/batch_inference_package/
      cd ${path.module}/../scripts/batch_inference_package
      pip3 install pandas scikit-learn joblib numpy -t . --quiet || true
    EOT
  }
}

# Lambda function for batch inference
resource "aws_lambda_function" "batch_inference" {
  filename         = data.archive_file.batch_inference_zip.output_path
  function_name    = "${local.name_prefix}-batch-inference"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "batch_inference.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.batch_inference_zip.output_base64sha256

  # VPC Configuration for existing VPC
  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DATA_BUCKET      = aws_s3_bucket.data_bucket.bucket
      ARTIFACTS_BUCKET = aws_s3_bucket.artifacts_bucket.bucket
      AWS_REGION       = var.aws_region
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-batch-inference"
    Purpose = "Batch ML Inference"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.batch_inference_logs,
    aws_security_group.lambda_sg,
    data.archive_file.batch_inference_zip
  ]
}

# Security Group for Lambda functions
resource "aws_security_group" "lambda_sg" {
  name_prefix = "${local.name_prefix}-lambda-sg"
  vpc_id      = local.vpc_id
  description = "Security group for Lambda functions"

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-sg"
    Purpose = "Lambda Security Group"
  })
}

# CloudWatch Log Group for Batch Inference Lambda
resource "aws_cloudwatch_log_group" "batch_inference_logs" {
  name              = "/aws/lambda/${local.name_prefix}-batch-inference"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-batch-inference-logs"
    Purpose = "Batch Inference Logging"
  })
}

# CloudWatch Alarms for Lambda monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"

  dimensions = {
    FunctionName = aws_lambda_function.ml_processor.function_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-errors-alarm"
    Purpose = "Lambda Error Monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "240000" # 4 minutes (240 seconds * 1000 ms)
  alarm_description   = "This metric monitors Lambda function duration"

  dimensions = {
    FunctionName = aws_lambda_function.ml_processor.function_name
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-duration-alarm"
    Purpose = "Lambda Duration Monitoring"
  })
}
