# Networking Notes

## Enterprise Networking Concepts

This document summarizes the AWS networking concepts implemented and evaluated during the AWS Enterprise Networking Foundation project.

The environment is designed as a multi-AZ VPC foundation with separate public and private network tiers, layered network controls, and optional cost-sensitive connectivity components managed through Terraform.

## Implemented Networking Topics

- Custom VPC design
- CIDR planning and subnet allocation
- Multi-AZ public and private subnets
- Internet Gateway connectivity
- Public and private route tables
- Public subnet Internet routing
- Security groups for application, database, and management tiers
- Network ACLs for public and private subnet segmentation
- Availability Zone distribution and subnet associations
- Terraform-based network resource management

## Optional / Cost-Sensitive Networking Components

- NAT Gateway architecture
- Elastic IP allocation for NAT Gateway
- Private subnet Internet routing through NAT
- Bastion host connectivity for administrative access

The NAT Gateway and bastion host configurations are retained in the active Terraform configuration but are disabled by default through feature-control variables to avoid unnecessary AWS charges.

## Concepts Evaluated for Future Enhancement

The following networking capabilities were considered during the project but are not currently deployed:

- VPC endpoints
- VPC Flow Logs
- Additional centralized network monitoring
- Expanded private-service connectivity

These capabilities can be incorporated in future iterations without changing the core VPC architecture.