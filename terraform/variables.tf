variable "aws_region" {
  description = "AWS region where networking resources will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used for tagging and naming project resources."
  type        = string
  default     = "networking-enterprise-foundation"
}

variable "environment" {
  description = "Environment name for this deployment."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag for cost tracking and accountability."
  type        = string
  default     = "cloud-portfolio"
}