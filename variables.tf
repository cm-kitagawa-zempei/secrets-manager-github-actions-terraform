variable "github_org_or_user" {
  description = "GitHub organization name (for org repos) or username (for personal repos)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}
