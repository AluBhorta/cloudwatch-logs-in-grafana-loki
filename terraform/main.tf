# vars
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of already existing EKS cluster"
  type        = string
  #default     = "eks-demo"
}

variable "namespace" {
  description = "Namespace of Loki installation"
  type        = string
  default     = "monitoring"
}

variable "serviceaccount-loki" {
  description = "Service account of loki installation"
  type        = string
  default     = "loki-sa"
}

variable "serviceaccount-fluentd" {
  description = "Service account of fluentd installation"
  type        = string
  default     = "fluentd-sa"
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
  bucket_prefix = "loki-data-"
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
      variable = "${local.oidc_id}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.serviceaccount-loki}"]
    }

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
  name               = "loki-role"
  assume_role_policy = data.aws_iam_policy_document.loki-oidc-trust-relation.json

  managed_policy_arns = [
    aws_iam_policy.loki-policy.arn
  ]
}

resource "aws_iam_policy" "fluentd-policy" {
  name = "fluentd-policy"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:DescribeLogStreams",
            "logs:GetLogEvents",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

data "aws_iam_policy_document" "fluentd-oidc-trust-relation" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_id}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.serviceaccount-fluentd}"]
    }

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

resource "aws_iam_role" "fluentd" {
  name               = "fluentd-role"
  assume_role_policy = data.aws_iam_policy_document.fluentd-oidc-trust-relation.json

  managed_policy_arns = [
    aws_iam_policy.fluentd-policy.arn
  ]
}

# resource "aws_cloudwatch_log_group" "test-log-group" {
#   name              = "test-log-group"
#   retention_in_days = 30
# }

# out
output "s3_bucket" {
  description = "s3 bucket"
  value       = aws_s3_bucket.loki-data.id
}

output "loki_role_arn" {
  description = "loki role arn"
  value       = aws_iam_role.loki.arn
}

output "fluentd_role_arn" {
  description = "fluentd role arn"
  value       = aws_iam_role.fluentd.arn
}

# output "log_group_name" {
#   description = "log group name"
#   value       = aws_cloudwatch_log_group.test-log-group.name
# }
