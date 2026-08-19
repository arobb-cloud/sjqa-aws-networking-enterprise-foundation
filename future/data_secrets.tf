
data "aws_secretsmanager_secret_version" "rds_postgres_admin_current" {
  secret_id = aws_secretsmanager_secret.rds_postgres_admin.id

  depends_on = [
    aws_secretsmanager_secret_version.rds_postgres_admin
  ]
}