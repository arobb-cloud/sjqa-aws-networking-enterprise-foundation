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
  description = "ID of the project VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "ID of the public subnet in Availability Zone A."
  value       = aws_subnet.public_a.id
}

output "private_subnet_a_id" {
  description = "ID of the private subnet in Availability Zone A."
  value       = aws_subnet.private_a.id
}

output "public_subnet_b_id" {
  description = "ID of the public subnet in Availability Zone B."
  value       = aws_subnet.public_b.id
}

output "private_subnet_b_id" {
  description = "ID of the private subnet in Availability Zone B."
  value       = aws_subnet.private_b.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}

output "database_security_group_id" {
  description = "ID of the database security group."
  value       = aws_security_group.database.id
}

output "application_security_group_id" {
  description = "ID of the application security group."
  value       = aws_security_group.application.id
}

output "management_security_group_id" {
  description = "ID of the management security group."
  value       = aws_security_group.management.id
}

output "public_network_acl_id" {
  description = "ID of the network ACL associated with the public subnets."
  value       = aws_network_acl.public.id
}

output "private_network_acl_id" {
  description = "ID of the network ACL associated with the private subnets."
  value       = aws_network_acl.private.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway when enabled."
  value       = var.enable_nat_gateway ? aws_nat_gateway.nat_a[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP address assigned to the NAT Gateway Elastic IP when enabled."
  value       = var.enable_nat_gateway ? aws_eip.nat_a[0].public_ip : null
}

output "bastion_instance_id" {
  description = "EC2 instance ID of the bastion host when enabled."
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host when enabled."
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}