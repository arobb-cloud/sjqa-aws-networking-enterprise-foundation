data "aws_secretsmanager_secret" "rds_postgres_admin" {
  name = aws_secretsmanager_secret.rds_postgres_admin.name
}

data "aws_secretsmanager_secret_version" "rds_postgres_admin_current" {
  secret_id = data.aws_secretsmanager_secret.rds_postgres_admin.id
}