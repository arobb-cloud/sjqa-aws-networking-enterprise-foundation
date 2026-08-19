resource "aws_secretsmanager_secret" "rds_postgres_admin" {
  name        = "${var.project_name}-${var.environment}-rds-postgres-admin"
  description = "Admin credentials for RDS PostgreSQL"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Compliance  = "Phase-10-Enterprise-Hardening"
  }
}

resource "aws_secretsmanager_secret_version" "rds_postgres_admin" {
  secret_id = aws_secretsmanager_secret.rds_postgres_admin.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}