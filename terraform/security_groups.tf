resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-database-sg"
  description = "Security Group for PostgreSQL databases"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Database"
  }
}

resource "aws_security_group" "application" {
  name        = "${var.project_name}-${var.environment}-application-sg"
  description = "Security Group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-application-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Application"
  }
}

resource "aws_security_group" "management" {
  name        = "${var.project_name}-${var.environment}-management-sg"
  description = "Security Group for Bastion or Management hosts"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-management-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Management"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "Allow PostgreSQL from Application Security Group"
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_management" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.management.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Allow SSH from Management Security Group"
}

resource "aws_vpc_security_group_egress_rule" "database_all_outbound" {
  security_group_id = aws_security_group.database.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "application_all_outbound" {
  security_group_id = aws_security_group.application.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "management_all_outbound" {
  security_group_id = aws_security_group.management.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}