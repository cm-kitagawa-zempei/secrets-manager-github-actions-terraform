terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================
# OIDC Provider for GitHub Actions
# ============================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# ============================================
# IAM Role for GitHub Actions
# ============================================
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 特定のリポジトリからのみアクセスを許可
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org_or_user}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-secrets-manager-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# ============================================
# IAM Policy for Secrets Manager Access
# ============================================
data "aws_iam_policy_document" "secrets_manager_access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }
}

resource "aws_iam_role_policy" "secrets_manager_access" {
  name   = "secrets-manager-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.secrets_manager_access.json
}

# ============================================
# Secrets Manager Secret
# ============================================
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "sample/db-credentials"
  description = "Database credentials for sample application"

  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    host     = "db.example.com"
    port     = 5432
    username = "app_user"
    password = "initial-password-v1"
    database = "myapp"
    version  = "v1" # ローテーション確認用
  })
}

