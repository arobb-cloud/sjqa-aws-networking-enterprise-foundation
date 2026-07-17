# AWS Enterprise Networking Foundation

Production-style AWS networking infrastructure built with Terraform demonstrating enterprise cloud architecture, secure networking, Infrastructure as Code (IaC), and operational best practices.

---

## Project Overview

This project implements a secure, production-inspired AWS networking environment using Terraform. The infrastructure includes a multi-tier VPC architecture, public and private subnets across multiple Availability Zones, network security controls, a private Amazon RDS PostgreSQL database, monitoring, logging, and enterprise documentation.

The project was developed to strengthen practical experience in Cloud Engineering, Cloud Database Engineering, Database Reliability Engineering (DBRE), and Cloud Database Migration.

---

## Objectives

The primary goals of this project were to:

- Build AWS infrastructure using Infrastructure as Code (Terraform)
- Design secure VPC networking following AWS best practices
- Deploy an encrypted Amazon RDS PostgreSQL database
- Implement IAM least-privilege access
- Integrate monitoring and auditing services
- Practice operational documentation used in enterprise environments
- Create a portfolio project demonstrating production-style cloud engineering skills

---

## Architecture

High-Level Components

- Amazon VPC
- Public and Private Subnets
- Multi-AZ Network Design
- Internet Gateway
- Route Tables
- Network ACLs
- Security Groups
- Bastion Host
- Amazon RDS PostgreSQL
- IAM Roles and Policies
- AWS Secrets Manager
- Amazon CloudWatch
- AWS CloudTrail

For a detailed architecture explanation and diagrams, see:

📁 architecture/architecture.md

---

## Technologies Used

### Cloud

- Amazon Web Services (AWS)

### Infrastructure as Code

- Terraform

### Database

- Amazon RDS PostgreSQL

### Networking

- VPC
- Subnets
- Route Tables
- Internet Gateway
- Network ACLs
- Security Groups

### Security

- IAM
- AWS Secrets Manager
- Encryption at Rest

### Monitoring & Logging

- Amazon CloudWatch
- AWS CloudTrail

### DevOps

- Git
- GitHub
- GitHub Actions

---

## Features

- Infrastructure deployed using Terraform
- Multi-AZ VPC architecture
- Public and private subnet design
- Secure RDS PostgreSQL deployment
- Bastion host administration
- Network security with Security Groups and NACLs
- IAM least-privilege implementation
- CloudWatch monitoring
- CloudTrail auditing
- Enterprise documentation

---

## Repository Structure

architecture/
diagrams/
future/
terraform/
docs/
screenshots/
.github/
	workflows/
README.md


## Documentation

| Document | Description |
|-----------|-------------|
| [Architecture](architecture/architecture.md) | High-level infrastructure design and diagrams |
| [Deployment Guide](docs/deployment-guide.md) | Step-by-step deployment instructions |
| [Security Guide](docs/security.md) | Security controls and IAM design |
| [Troubleshooting Guide](docs/troubleshooting-guide.md) | Common issues and resolutions |
| [Cost Optimization](docs/cost-optimization.md) | Cost-saving decisions and recommendations |
| [Operational Runbook](docs/operational-runbook.md) | Verification and maintenance procedures |
| [Lessons Learned](docs/lessons-learned.md) | Technical observations and project reflections |


## Deployment

High-Level Deployment Process

1. Clone the repository
2. Configure AWS credentials
3. Initialize Terraform
4. Review the execution plan
5. Apply the infrastructure
6. Validate deployment
7. Destroy resources when finished (training environment)

Detailed deployment instructions are available in:

📁 docs/deployment-guide.md


## CI/CD Pipeline

GitHub Actions automatically validates Terraform code by executing:

- terraform fmt
- terraform init
- terraform validate

Future enhancements include:

- Automated terraform plan
- Pull Request validation
- Security scanning
- Policy-as-Code

---

## Security

Security considerations implemented include:

- Private database deployment
- IAM least-privilege access
- AWS Secrets Manager
- Encrypted RDS storage
- Security Groups
- Network ACLs
- CloudTrail auditing
- CloudWatch monitoring

Additional details are available in:

📁 docs/security.md

---

## Cost Optimization

To minimize AWS costs during project development:

- NAT Gateway deployment was deferred
- Free Tier resources were used where possible
- Infrastructure was destroyed after validation
- Small instance sizes were selected
- Storage allocation was minimized

Additional information:

📁 docs/cost-optimization.md

---

## Screenshots

Project screenshots include:

- Terraform Apply
- AWS VPC
- Public & Private Subnets
- Security Groups
- Network ACLs
- Amazon RDS
- CloudWatch Dashboard
- GitHub Actions Pipeline

Available in:

📁 screenshots/

---


## Lessons Learned

This project provided hands-on experience with:

- Terraform state management
- AWS networking architecture
- Multi-AZ infrastructure design
- Network security implementation
- RDS deployment
- PostgreSQL deployment on AWS
- Secrets management
- CloudWatch monitoring
- Infrastructure documentation
- Enterprise deployment workflows

Additional project reflections are documented in:

📁 docs/lessons-learned.md

---


## Future Improvements

Potential enhancements include:

- Add AWS Config
- Add GuardDuty
- Implement automated Terraform plan reviews
- Introduce remote state locking
- Expand monitoring dashboards
- Build reusable Terraform modules

## Author

Built as part of a Cloud Engineering and Database Reliability Engineering portfolio demonstrating production-style AWS infrastructure, Infrastructure as Code, operational documentation, and cloud operations best practices.