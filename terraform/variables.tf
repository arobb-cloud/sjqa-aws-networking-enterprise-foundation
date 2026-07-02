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

# For Bastion host creation
#variable "ssh_key_name" {
#  description = "Name of the EC2 key pair for bastion access"
#  type        = string
#  default     = null
#}

# RDS Instance
#variable "db_name" {
#  description = "Initial PostgreSQL database name"
#  type        = string
 # default     = "appdb"
#}

#variable "db_username" {
#  description = "Master username for PostgreSQL"
#  type        = string
#  default     = "dbadmin"
#}

#variable "db_password" {
#  description = "Master password for PostgreSQL"
#  type        = string
#  sensitive   = true
#}