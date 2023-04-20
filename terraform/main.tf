# providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.15.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }

  required_version = "> 1.2.0"
}

# vars
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of EKS cluster"
  type = string
  default = "eks-demo"
}

variable "namespace" {
  description = "Namespace of Loki installation"
  type        = string
  default = "monitoring"
}

variable "oidc_id" {
  description = "OIDC provider ID"
  type        = string
}

variable "serviceaccount" {
  description = "Service account of Loki installation"
  type        = string
  default     = "loki-sa"
}

# main
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "current" {
  name = var.cluster_name
}

data "aws_iam_policy_document" "oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.${var.region}.amazonaws.com/id/${var.oidc_id}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.serviceaccount}"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.${var.region}.amazonaws.com/id/${var.oidc_id}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${var.oidc_id}"
      ]
      type        = "Federated"
    }
  }
}

resource "aws_s3_bucket" "loki-data" {
  bucket_prefix = "loki-data-"
  force_destroy = false
}

resource "aws_s3_bucket_policy" "grant-access" {
  bucket = aws_s3_bucket.loki-data.id
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
            Sid: "Statement1",
            Effect: "Allow",
            Principal: {
                AWS: aws_iam_role.loki.arn  
            },
            Action: [
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObject",
              "s3:ListBucket"
            ],
            Resource: [
	      aws_s3_bucket.loki-data.arn,
	      "${aws_s3_bucket.loki-data.arn}/*"
            ]
        }
    ]
  })
}

resource "aws_iam_role" "loki" {
  name               = "loki-storage-role"
  assume_role_policy = data.aws_iam_policy_document.oidc.json

  inline_policy {}
}

resource "aws_iam_policy" "loki" {
  name        = "LokiStorageAccessPolicy"
  path        = "/"
  description = "Allows Loki to access bucket"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
            Effect: "Allow",
            Action: [
              "s3:ListBucket",
              "s3:PutObject",
              "s3:GetObject",
              "s3:DeleteObject"
	          ],
            Resource: [
		    aws_s3_bucket.loki-data.arn,
		    "${aws_s3_bucket.loki-data.arn}/*"
	    ]
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "loki-attach" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki.arn
}

# outputs
output "s3_bucket" {
  description = "s3 bucket for loki storage"
  value       = aws_s3_bucket.loki-data.id
}
output "iam_role" {
  description = "iam role for loki"
  value       = aws_iam_role.loki.arn
}
