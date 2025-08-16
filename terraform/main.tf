# AWS Machine Learning Project - Main Terraform Configuration
# Region: Ireland (eu-west-1)
# Profile: raj-private

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.aws_region
      Owner       = "raj-private"
    }
  }
}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get existing VPC (first available VPC that's not default)
data "aws_vpc" "existing" {
  count = 1
  
  filter {
    name   = "is-default"
    values = ["false"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get private subnets from existing VPC
data "aws_subnets" "private" {
  count = length(data.aws_vpc.existing) > 0 ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*private*", "*Private*"]
  }
}

# Get public subnets from existing VPC (for NAT gateways if needed)
data "aws_subnets" "public" {
  count = length(data.aws_vpc.existing) > 0 ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*public*", "*Public*"]
  }
}

# Get all subnets from existing VPC as fallback
data "aws_subnets" "all_existing" {
  count = length(data.aws_vpc.existing) > 0 ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
}

# Fallback to default VPC if no custom VPC exists
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Local values for common configurations
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # VPC selection logic - use existing VPC if available, otherwise default
  has_existing_vpc = length(data.aws_vpc.existing) > 0
  has_private_subnets = local.has_existing_vpc && length(data.aws_subnets.private) > 0 ? length(data.aws_subnets.private[0].ids) > 0 : false
  has_public_subnets = local.has_existing_vpc && length(data.aws_subnets.public) > 0 ? length(data.aws_subnets.public[0].ids) > 0 : false
  has_any_existing_subnets = local.has_existing_vpc && length(data.aws_subnets.all_existing) > 0 ? length(data.aws_subnets.all_existing[0].ids) > 0 : false
  
  # Select VPC and subnets with proper fallback logic
  vpc_id = local.has_existing_vpc ? data.aws_vpc.existing[0].id : data.aws_vpc.default.id
  
  # Subnet selection priority: private -> public -> all existing -> default
  subnet_ids = (
    local.has_private_subnets ? data.aws_subnets.private[0].ids :
    local.has_public_subnets ? data.aws_subnets.public[0].ids :
    local.has_any_existing_subnets ? data.aws_subnets.all_existing[0].ids :
    data.aws_subnets.default_subnets.ids
  )
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Region      = var.aws_region
    Owner       = "raj-private"
    VPC         = local.vpc_id
  }
  
  # Naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_suffix = random_string.suffix.result
}
