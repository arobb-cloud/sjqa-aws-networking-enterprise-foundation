resource "aws_secretsmanager_secret" "rds_postgres_admin" {
  name        = "${var.project_name}-${var.environment}-rds-postgres-admin"
  description = "Admin credentials for RDS PostgreSQL"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Compliance  = "Phase-30-Enterprise-Hardening"
  }
}