# vars
variable "region" {
  description = "AWS region"
  type        = string
  # default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Name of already existing EKS cluster"
  type        = string
}

# prov
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

provider "aws" {
  region = var.region
}

# main
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "current" {
  name = var.cluster_name
}

locals {
  oidc_id = replace(data.aws_eks_cluster.current.identity[0].oidc[0].issuer, "https://", "")
}

resource "aws_s3_bucket" "loki-data" {
  bucket_prefix = "loki-storage-"
}

resource "aws_s3_bucket_policy" "grant-access" {
  bucket = aws_s3_bucket.loki-data.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "Statement1",
        Effect : "Allow",
        Principal : {
          AWS : aws_iam_role.loki.arn
        },
        Action : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource : [
          aws_s3_bucket.loki-data.arn,
          "${aws_s3_bucket.loki-data.arn}/*"
        ]
      }
    ]
  })
}


data "aws_iam_policy_document" "loki-oidc-trust-relation" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_id}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_id}"
      ]
      type = "Federated"
    }
  }
}

resource "aws_iam_policy" "loki-policy" {
  name = "loki-policy"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource : [
          aws_s3_bucket.loki-data.arn,
          "${aws_s3_bucket.loki-data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "loki" {
  name               = "logging-loki-role"
  assume_role_policy = data.aws_iam_policy_document.loki-oidc-trust-relation.json

  managed_policy_arns = [
    aws_iam_policy.loki-policy.arn
  ]
}

# out
output "s3_bucket" {
  description = "s3 bucket"
  value       = aws_s3_bucket.loki-data.id
}

output "loki_role_arn" {
  description = "loki role arn"
  value       = aws_iam_role.loki.arn
}

