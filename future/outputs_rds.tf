output "aws_region" {
  description = "AWS region used for deployment."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name."
  value       = var.project_name
}

output "environment" {
  description = "Deployment environment."
  value       = var.environment
}

output "name_prefix" {
  description = "Standard naming prefix for AWS resources."
  value       = local.name_prefix
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_a.id
}

output "private_subnet_id" {
  value = aws_subnet.private_a.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "database_security_group_id" {
  value = aws_security_group.database.id
}

output "application_security_group_id" {
  value = aws_security_group.application.id
}

output "management_security_group_id" {
  value = aws_security_group.management.id
}

output "public_network_acl_id" {
  value = aws_network_acl.public.id
}

output "private_network_acl_id" {
  value = aws_network_acl.private.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

# RDS Outputs
output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "rds_db_name" {
  value = aws_db_instance.postgres.db_name
}