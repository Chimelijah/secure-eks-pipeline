terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # LOCK PRODUCER: Pin to an older v5 release before they removed legacy EKS properties
      version = "5.31.0" 
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Vulnerable IAM Role for EKS Nodes
resource "aws_iam_role" "insecure_node_role" {
  name = "insecure-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# The Anti-Pattern: Giving the whole node full S3 access
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.insecure_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# EKS Cluster (Kept at v19 natively matching your workspace cache)
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.21.0"
  cluster_name    = "devsecops-lab-cluster"
  cluster_version = "1.30"
  
  vpc_id          = "vpc-00c282900994e135c"                # Replace with your Default VPC ID
  subnet_ids      = ["subnet-0a6251e20c03bd53c", "subnet-0c7571dc4066bdb64"]  # Replace with your subnets

  
# --- ADD THESE TWO LINES TO ENABLE PUBLIC ENDPOINT ACCESS ---
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  # -----------------------------------------------------------

eks_managed_node_groups = {
    vulnerable_nodes = {
      min_size     = 1
      max_size     = 2
      desired_size = 1
      iam_role_arn = aws_iam_role.insecure_node_role.arn
    }
  }
}

resource "aws_iam_policy" "app_s3_policy" {
  name        = "StrictAppS3Policy"
  description = "Allows reading only from the specific app bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::my-specific-app-bucket/*"] # Restricted to ONE bucket
    }]
  })
}

# SECURE: Map the IAM Role to the Kubernetes Service Account via OIDC
module "iam_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "SecureAppRole"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:secure-app-sa"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.app_s3_policy.arn
  }
}
