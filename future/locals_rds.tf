locals {
  rds_admin_secret = jsondecode(
    data.aws_secretsmanager_secret_version.rds_postgres_admin_current.secret_string
  )

  rds_admin_username = local.rds_admin_secret.username
  rds_admin_password = local.rds_admin_secret.password
}
