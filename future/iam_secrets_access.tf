resource "aws_iam_policy" "read_rds_secret" {
  name        = "${var.project_name}-${var.environment}-read-rds-secret"
  description = "Least-privilege read access to the RDS PostgreSQL admin secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_postgres_admin.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_read_rds_secret" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.read_rds_secret.arn
}