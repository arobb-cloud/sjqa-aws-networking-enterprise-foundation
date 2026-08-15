# Deployment Guide

## 1. Purpose

This guide documents the process for deploying, validating, and removing the AWS Networking Enterprise Foundation environment using Terraform.

The deployment builds a multi-AZ AWS networking foundation designed to support private application and database workloads while incorporating network segmentation, security controls, monitoring, encryption, secrets management, and operational safeguards.

The project is intended as a hands-on infrastructure engineering environment rather than a permanently running production workload. Resources that can generate ongoing AWS charges may therefore be deployed temporarily for validation and removed when testing is complete.

---

## 2. Deployment Model

The environment was developed incrementally using Terraform. Infrastructure components were introduced and validated in phases rather than deploying the complete architecture at once.

The deployment model follows the general workflow:

```text
Terraform Configuration
        │
        ▼
terraform fmt
        │
        ▼
terraform init
        │
        ▼
terraform validate
        │
        ▼
terraform plan
        │
        ▼
Review Planned Changes
        │
        ▼
terraform apply
        │
        ▼
AWS Deployment
        │
        ▼
AWS Console / Terraform Validation
        │
        ▼
Capture Validation Evidence
        │
        ▼
terraform destroy
        │
        ▼
Environment Removed
```

Some components were intentionally treated differently because of cost or security considerations.

For example:

* The NAT Gateway architecture was designed and documented but was not maintained as part of the active environment because NAT Gateways generate hourly and data-processing charges.
* The bastion host pattern was documented as a management-access architecture but was not maintained as a continuously running EC2 instance.
* Amazon RDS for PostgreSQL was deployed and validated during the project and later destroyed to prevent unnecessary charges.
* Secrets Manager stores sensitive database credentials outside of the Terraform source code.

This approach demonstrates the target architecture while maintaining control over lab and portfolio costs.

---

## 3. Prerequisites

The following tools and access are required before deploying the environment:

* AWS account
* AWS CLI
* Terraform
* Git
* Visual Studio Code or another code editor
* PowerShell or another supported terminal
* AWS credentials with sufficient permissions to provision the required resources

Verify the installed tools before deployment:

```powershell
aws --version
terraform version
git --version
```

Verify AWS authentication:

```powershell
aws sts get-caller-identity
```

The command should return the AWS account and IAM identity being used for the deployment.

> **Security Note:** Do not store AWS access keys, database passwords, secret values, or other credentials in the GitHub repository.

---

## 4. Repository Preparation

Clone the project repository and move into the Terraform directory.

Example:

```powershell
git clone <repository-url>
cd <repository-name>
cd terraform
```

Review the Terraform configuration before deployment.

The Terraform directory contains infrastructure definitions for components such as:

* VPC
* Public and private subnets
* Internet Gateway
* Route tables
* Security Groups
* Network ACLs
* Multi-AZ networking
* RDS PostgreSQL
* CloudWatch monitoring
* SNS alerting
* Secrets Manager
* IAM and security controls

Review the variable definitions and example configuration before creating local variable values.

Sensitive local files should remain excluded from Git through `.gitignore`.

---

## 5. Terraform Initialization

Initialize the Terraform working directory:

```powershell
terraform init
```

Terraform downloads the required providers and prepares the working directory.

A successful initialization should end with a message similar to:

```text
Terraform has been successfully initialized!
```

Initialization should be performed when:

* The repository is cloned for the first time.
* Provider requirements change.
* Terraform modules are added or modified.
* Backend configuration changes.

---

## 6. Terraform Validation

Format the Terraform configuration:

```powershell
terraform fmt -recursive
```

Validate the configuration:

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

Formatting and validation should be completed before generating a deployment plan.

These checks help identify:

* Terraform syntax errors
* Invalid resource references
* Incorrect argument usage
* Configuration inconsistencies

---

## 7. Deployment Planning

Generate a Terraform execution plan:

```powershell
terraform plan
```

Review the plan carefully before applying changes.

The plan should be checked for:

* Resources being created
* Resources being modified
* Resources being destroyed
* Unexpected infrastructure changes
* Cost-sensitive resources
* Security-related changes

Terraform displays a summary similar to:

```text
Plan: X to add, X to change, X to destroy.
```

The plan should not be treated as an automatic approval to deploy. The proposed changes should be reviewed before proceeding.

Particular attention should be given to resources such as:

* NAT Gateways
* EC2 instances
* RDS instances
* Secrets Manager secrets
* CloudWatch resources

These services may generate ongoing charges.

---

## 8. Core Infrastructure Deployment

After reviewing the Terraform plan, deploy the approved infrastructure:

```powershell
terraform apply
```

Terraform displays the proposed changes and requests confirmation.

Enter:

```text
yes
```

to proceed.

The core networking architecture includes:

```text
AWS VPC
│
├── Availability Zone A
│   ├── Public Subnet
│   └── Private Subnet
│
├── Availability Zone B
│   ├── Public Subnet
│   └── Private Subnet
│
├── Internet Gateway
├── Route Tables
├── Security Groups
└── Network ACLs
```

The private subnet architecture provides the foundation for private database workloads such as Amazon RDS for PostgreSQL.

Resources should only be deployed when they are required for validation or demonstration.

---

## 9. Optional / Cost-Sensitive Resources

Some infrastructure components were intentionally not maintained as continuously deployed resources.

### NAT Gateway

A NAT Gateway architecture was designed to provide outbound Internet access from private subnets without exposing those subnets directly to inbound Internet traffic.

Conceptually:

```text
Private Subnet
      │
      ▼
Private Route Table
      │
      ▼
NAT Gateway
      │
      ▼
Public Subnet
      │
      ▼
Internet Gateway
      │
      ▼
Internet
```

The NAT Gateway was not maintained as part of the active portfolio environment because it generates ongoing hourly and data-processing charges.

### Bastion Host

A bastion host architecture was also designed to provide controlled administrative access:

```text
Internet
   │
   ▼
Public Subnet
   │
   ▼
Bastion Host
   │
   ▼
Private Resources
```

The bastion host was not maintained as a continuously running EC2 instance because the primary objective was to demonstrate the architecture without incurring unnecessary compute costs.

### RDS PostgreSQL

Amazon RDS for PostgreSQL was deployed during the project to validate:

* Private subnet placement
* DB subnet groups
* Database Security Groups
* PostgreSQL configuration
* Encryption
* Backup configuration
* Monitoring integration

After successful validation, the RDS instance was destroyed to prevent ongoing charges.

---

## 10. Secrets Configuration

Database credentials should not be committed to Terraform source files or the GitHub repository.

AWS Secrets Manager is used to provide a centralized location for sensitive database credentials.

Terraform creates the Secrets Manager secret resource.

The sensitive secret value should be configured separately so that plaintext credentials are not stored in the Terraform source code.

The general workflow is:

```text
Terraform
   │
   ▼
Create Secrets Manager Secret
   │
   ▼
AWS Secrets Manager
   │
   ▼
Configure Secret Value
   │
   ▼
Database Credentials Protected
```

Never include actual secret values in:

* `terraform.tf`
* `.tfvars.example` files
* README files
* documentation
* screenshots
* Git commits

If a credential is accidentally committed to Git, the credential should be considered compromised and rotated.

---

## 11. Deployment Validation

After deployment, validate the environment using both Terraform and the AWS Management Console.

### Terraform Validation

Review Terraform-managed resources:

```powershell
terraform state list
```

Review Terraform outputs:

```powershell
terraform output
```

### AWS Console Validation

Verify the following infrastructure components where applicable:

**VPC**

Confirm that the project VPC exists and uses the expected CIDR range.

**Subnets**

Confirm that public and private subnets exist across the intended Availability Zones.

**Route Tables**

Confirm that public subnets use the public route table and that the Internet Gateway route exists where expected.

**Network ACLs**

Confirm that public and private subnets are associated with the appropriate NACLs.

**Security Groups**

Confirm that Security Group rules enforce the intended access relationships between management, application, and database tiers.

**RDS**

When deployed, confirm that the PostgreSQL instance:

* Is deployed in the intended private subnet architecture.
* Is not publicly accessible.
* Uses the expected database Security Group.
* Has storage encryption enabled.
* Uses the configured backup retention settings.

**CloudWatch**

Confirm that the configured RDS alarms and monitoring resources exist.

**SNS**

Confirm that the alerting topic used by CloudWatch exists and is correctly associated with the alarms.

**Secrets Manager**

Confirm that the database credential secret exists.

Do not expose the secret value while capturing screenshots or project evidence.

---

## 12. Terraform Outputs

Terraform outputs provide useful infrastructure information after deployment.

Display all outputs:

```powershell
terraform output
```

Outputs may include information such as:

* VPC ID
* Public subnet IDs
* Private subnet IDs
* Security Group IDs
* RDS endpoint
* Other infrastructure identifiers

Sensitive values should be marked appropriately and should never be included in public documentation.

Terraform outputs can also be used when validating relationships between deployed AWS resources.

---

## 13. Environment Teardown

Because this project is designed as a cost-controlled lab and portfolio environment, resources should be removed when they are no longer required.

Before destroying the environment, review the Terraform destroy plan:

```powershell
terraform plan -destroy
```

Then remove Terraform-managed resources:

```powershell
terraform destroy
```

Review the proposed destruction carefully.

Enter:

```text
yes
```

when ready to proceed.

After destruction, verify through the AWS Management Console that cost-generating resources have been removed.

Pay particular attention to:

* RDS instances
* EC2 instances
* NAT Gateways
* Elastic IP addresses
* CloudWatch resources
* Secrets Manager secrets
* Other resources that may generate ongoing charges

Some AWS resources may have retention or deletion behavior that requires additional verification.

---

## 14. Redeployment

The environment can be recreated from the Terraform configuration when additional testing or validation is required.

The normal redeployment sequence is:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

If Terraform has already been initialized and the provider/backend configuration has not changed, another initialization may not always be necessary. Running `terraform init` again is safe and can confirm that the working directory is properly initialized.

After redeployment:

1. Review Terraform outputs.
2. Validate the resources in AWS.
3. Configure required secret values.
4. Validate security controls.
5. Validate monitoring.
6. Perform the intended testing.
7. Destroy unnecessary cost-generating resources after testing.

---

## 15. Cost Considerations

Cost control was an explicit design consideration throughout the project.

The architecture includes AWS services that may generate charges even when resource utilization is low.

Primary cost-sensitive components include:

* NAT Gateway
* EC2
* Amazon RDS
* Elastic IP addresses
* Secrets Manager
* CloudWatch
* Data transfer

The project therefore uses several cost-control practices:

* Avoid maintaining a NAT Gateway when it is not required.
* Avoid maintaining an EC2 bastion host when it is not required.
* Destroy RDS instances after validation.
* Review Terraform plans before deployment.
* Destroy temporary infrastructure after testing.
* Verify resource removal through the AWS Management Console.
* Avoid assuming that all AWS services are covered by the AWS Free Tier.

Cost optimization is treated as an operational requirement rather than an afterthought.

---

## 16. Security Considerations

The deployment incorporates multiple layers of AWS security controls.

### Network Segmentation

Public and private subnets separate Internet-facing infrastructure from private workloads.

### Security Groups

Security Groups provide stateful resource-level traffic controls.

Database access should be limited to explicitly authorized sources rather than allowing unrestricted network access.

### Network ACLs

Network ACLs provide stateless subnet-level controls.

Because NACLs are stateless, both request and return traffic must be accounted for in the rule design.

### Private Database Deployment

RDS PostgreSQL is designed to operate in private subnets and should not be publicly accessible.

### Encryption

Database storage encryption protects RDS data at rest.

### Secrets Management

Sensitive database credentials are stored using AWS Secrets Manager rather than being committed to source control.

### IAM Least Privilege

AWS identities and resources should receive only the permissions required to perform their intended functions.

### Terraform Security

The following should never be committed to GitHub:

```text
terraform.tfstate
terraform.tfstate.*
.terraform/
terraform.tfvars
*.tfplan
AWS credentials
Private SSH keys
Database passwords
Secret values
```

The repository `.gitignore` should be reviewed before publishing the project.

---

## 17. Troubleshooting References

Deployment problems should first be investigated using Terraform output and AWS service information.

Useful Terraform commands include:

```powershell
terraform validate
terraform plan
terraform state list
terraform output
terraform providers
```

Common areas to investigate include:

* AWS authentication failures
* IAM permission errors
* Incorrect Terraform variables
* Resource dependency problems
* Security Group rules
* NACL rules
* Route table associations
* Subnet configuration
* RDS deployment failures
* CloudWatch configuration
* Secrets Manager access

Detailed problems encountered while building the environment and their resolutions are documented separately in:

```text
docs/troubleshooting.md
```

This keeps the Deployment Guide focused on the deployment lifecycle while the Troubleshooting Guide maintains detailed diagnostic procedures and project-specific resolutions.
