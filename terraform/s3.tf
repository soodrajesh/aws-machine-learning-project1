# S3 Buckets for ML Project Data and Artifacts

# S3 Bucket for Raw Data
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${local.name_prefix}-data-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-data-bucket"
    Purpose     = "ML Data Storage"
    DataType    = "Raw and Processed Data"
  })
}

# S3 Bucket for Model Artifacts
resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = "${local.name_prefix}-artifacts-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-artifacts-bucket"
    Purpose     = "ML Model Artifacts"
    DataType    = "Trained Models and Outputs"
  })
}

# S3 Bucket for SageMaker Code
resource "aws_s3_bucket" "code_bucket" {
  bucket = "${local.name_prefix}-code-${local.bucket_suffix}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-code-bucket"
    Purpose     = "SageMaker Code Repository"
    DataType    = "Training Scripts and Notebooks"
  })
}

# Versioning Configuration for Data Bucket
resource "aws_s3_bucket_versioning" "data_bucket_versioning" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Versioning Configuration for Artifacts Bucket
resource "aws_s3_bucket_versioning" "artifacts_bucket_versioning" {
  bucket = aws_s3_bucket.artifacts_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Versioning Configuration for Code Bucket
resource "aws_s3_bucket_versioning" "code_bucket_versioning" {
  bucket = aws_s3_bucket.code_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-side Encryption for Data Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket_encryption" {
  count  = var.s3_encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Server-side Encryption for Artifacts Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_bucket_encryption" {
  count  = var.s3_encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.artifacts_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Server-side Encryption for Code Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "code_bucket_encryption" {
  count  = var.s3_encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.code_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Public Access Block for Data Bucket
resource "aws_s3_bucket_public_access_block" "data_bucket_pab" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public Access Block for Artifacts Bucket
resource "aws_s3_bucket_public_access_block" "artifacts_bucket_pab" {
  bucket = aws_s3_bucket.artifacts_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public Access Block for Code Bucket
resource "aws_s3_bucket_public_access_block" "code_bucket_pab" {
  bucket = aws_s3_bucket.code_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration for Data Bucket
resource "aws_s3_bucket_lifecycle_configuration" "data_bucket_lifecycle" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    id     = "data_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete old versions after 365 days
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Lifecycle Configuration for Artifacts Bucket
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_bucket_lifecycle" {
  bucket = aws_s3_bucket.artifacts_bucket.id

  rule {
    id     = "artifacts_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Move to IA after 60 days (models accessed less frequently)
    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }

    # Keep model artifacts longer - move to Glacier after 180 days
    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    # Delete old versions after 730 days (2 years)
    noncurrent_version_expiration {
      noncurrent_days = 730
    }
  }
}

# S3 Bucket Notification for Lambda Trigger
resource "aws_s3_bucket_notification" "data_bucket_notification" {
  bucket = aws_s3_bucket.data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ml_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".csv"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke,
    aws_lambda_function.ml_processor,
    aws_s3_bucket.data_bucket
  ]
}
