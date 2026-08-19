# Deployment Guide

## 1. Purpose

This guide documents the process for deploying, validating, and removing the AWS Networking Enterprise Foundation environment using Terraform.

The project defines a multi-AZ AWS networking foundation designed to support private application and database workloads while incorporating network segmentation and security controls, with additional database, monitoring, encryption, secrets-management, and hardening capabilities retained as staged configuration for future integration.

The project is intended as a hands-on infrastructure engineering environment rather than a permanently running production workload. Resources that can generate ongoing AWS charges may therefore be deployed temporarily for validation and removed when testing is complete.

---

## 2. Deployment Model

The environment was developed incrementally using Terraform. Infrastructure components were introduced and validated in phases rather than deploying the complete architecture at once.

The deployment model follows the general workflow:

```text
Repository / Terraform Configuration
        │
        ▼
terraform init
        │
        ▼
terraform fmt -check -recursive
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

- The NAT Gateway architecture was designed and documented but was intentionally not deployed during the project because NAT Gateways generate ongoing hourly and data-processing charges.
- The bastion host pattern was designed and documented as a management-access architecture but was intentionally not deployed during the project to avoid unnecessary EC2 compute charges.
- Amazon RDS for PostgreSQL was deployed and validated during the project and later destroyed to prevent unnecessary charges.
- AWS Secrets Manager provides the managed location for database credentials. The staged hardening configuration defines the secret resource, while the sensitive secret value is configured separately so that plaintext credentials are not stored in Terraform source code.

This approach demonstrates the target architecture while maintaining control over lab and portfolio costs.

---

## 3. Prerequisites

The following tools and access are required before deploying the environment:

- AWS account
- AWS CLI
- Terraform
- Git
- Visual Studio Code or another code editor
- PowerShell or another supported terminal
- AWS credentials with sufficient permissions to provision the required resources

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

The repository separates the active Terraform deployment configuration from staged infrastructure retained for future integration.

The `terraform/` directory is the active Terraform root and currently contains configuration for:

- VPC
- Public and private subnets
- Internet Gateway
- Route tables
- Security Groups
- Network ACLs
- Multi-AZ networking
- Optional NAT Gateway
- Optional bastion host
- Terraform variables, outputs, provider configuration, and dependency lock information

The `future/` directory contains staged infrastructure and hardening configuration that is not part of the current active Terraform root, including:

- Amazon RDS for PostgreSQL
- RDS CloudWatch monitoring
- SNS alerting
- AWS Secrets Manager
- IAM least-privilege secret access
- RDS-specific variables, locals, and outputs

These staged files document and preserve later project phases without causing those resources to be created when Terraform is executed from the `terraform/` directory.

Review `variables.tf` and `terraform.tfvars.example` before creating or modifying local deployment values.

A local `terraform.tfvars` file may be used for environment-specific values, but it is excluded from Git and must not contain credentials, database passwords, secret values, or other sensitive information intended for publication.

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

- The repository is cloned for the first time.
- Provider requirements change.
- Terraform modules are added or modified.
- Backend configuration changes.

---

## 6. Terraform Validation

Format the Terraform configuration:

```powershell
terraform fmt -check -recursive
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

- Terraform syntax errors
- Invalid resource references
- Incorrect argument usage
- Configuration inconsistencies

---

## 7. Deployment Planning

Before generating a plan, review the sanitized `terraform.tfvars.example` file and ensure that required local variable values have been configured appropriately.

The local `terraform.tfvars` file is excluded from Git and is intended only for environment-specific deployment values. Credentials, database passwords, and secret values should not be stored in that file.

```powershell
terraform plan
```

Review the plan carefully before applying changes.

The plan should be checked for:

- Resources being created
- Resources being modified
- Resources being destroyed
- Unexpected infrastructure changes
- Cost-sensitive resources
- Security-related changes

Terraform displays a summary similar to:

```text
Plan: X to add, X to change, X to destroy.
```

The plan should not be treated as an automatic approval to deploy. The proposed changes should be reviewed before proceeding.

Particular attention should be given to applicable cost-sensitive resources. In the active Terraform root this includes optional NAT Gateway and EC2 bastion resources; staged deployments may additionally include resources such as:

- RDS instances
- Secrets Manager secrets
- CloudWatch resources
- SNS resources

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

The NAT Gateway architecture was designed and documented but was intentionally not deployed during the project because NAT Gateways generate ongoing hourly and data-processing charges.

NAT Gateway creation is controlled by the `enable_nat_gateway` Terraform variable. The default value is `false`, so the NAT Gateway is not created unless it is explicitly enabled.

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

The bastion host architecture was designed and documented but was intentionally not deployed during the project because the management-access pattern could be demonstrated without maintaining a cost-generating EC2 instance.

Bastion host creation is controlled by the `enable_bastion` Terraform variable. The default value is `false`, so the EC2 bastion host is not created unless it is explicitly enabled.

When bastion deployment is enabled, the `ssh_key_name` variable must also be configured with an appropriate EC2 key pair name.

### RDS PostgreSQL

Amazon RDS for PostgreSQL was deployed and validated during an earlier project phase and later destroyed to prevent ongoing charges.

The current RDS Terraform configuration is retained in the `future/` directory rather than the active `terraform/` deployment root. Running Terraform from the `terraform/` directory therefore does not currently create the RDS instance.

The RDS deployment was used to validate:

- Private subnet placement
- DB subnet groups
- Database Security Groups
- PostgreSQL configuration
- Encryption
- Backup configuration
- Monitoring integration

---

## 10. Secrets Configuration

Database credentials should not be committed to Terraform source files or the GitHub repository.

AWS Secrets Manager is used to provide a centralized location for sensitive database credentials.

The staged hardening configuration in the `future/` directory defines the AWS Secrets Manager secret resource. When that configuration is integrated into the active Terraform deployment, Terraform can create the secret container while the sensitive secret value is configured separately so that plaintext credentials are not stored in Terraform source code.

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

- Terraform `.tf` files
- `.tfvars.example` files
- README files
- documentation
- screenshots
- Git commits

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

When the staged RDS configuration is deployed, confirm that the PostgreSQL instance:

- Is deployed in the intended private subnet architecture.
- Is not publicly accessible.
- Uses the expected database Security Group.
- Has storage encryption enabled.
- Uses the configured backup retention settings.

**CloudWatch**

When the staged RDS monitoring configuration is deployed, confirm that the configured CloudWatch alarms exist for RDS CPU utilization, free storage, database connections, freeable memory, read latency, and write latency. Verify that each alarm references the intended RDS DB instance and SNS alert topic.

**SNS**

When the staged SNS alerting configuration is deployed, confirm that the alerting topic exists and is correctly associated with the CloudWatch alarms.

**Secrets Manager**

When the staged Secrets Manager configuration is deployed, confirm that the database credential secret exists.

Do not expose the secret value while capturing screenshots or project evidence.

---

## 12. Terraform Outputs

Terraform outputs provide useful infrastructure information after deployment.

Display all outputs:

```powershell
terraform output
```

Depending on which infrastructure components are deployed, outputs may include information such as:

- VPC ID
- Public subnet IDs
- Private subnet IDs
- Security Group IDs
- RDS endpoint
- Other infrastructure identifiers

Sensitive values should be marked appropriately and should never be included in public documentation.

Terraform outputs can also be used when validating relationships between deployed AWS resources.

---

## 13. RDS Backup and Deletion Safeguards

The staged RDS PostgreSQL configuration in the `future/` directory represents a temporary portfolio and validation workload rather than a permanently running production database.

The staged RDS configuration uses:

```hcl
backup_retention_period = 1
deletion_protection     = false
skip_final_snapshot     = true
```

These settings were selected intentionally to support short-lived lab deployments and predictable Terraform teardown while minimizing ongoing AWS charges.

### Backup Retention

```hcl
backup_retention_period = 1
```

Automated backups are retained for one day while the database is deployed. This provides limited recovery capability appropriate for a temporary lab environment.

A production implementation would normally use a longer retention period based on recovery requirements, organizational policy, and recovery point objectives.

### Deletion Protection

```hcl
deletion_protection = false
```

Deletion protection is disabled so that the RDS instance can be removed during planned Terraform teardown.

For a production or persistent database, deletion protection should normally be enabled to reduce the risk of accidental database removal.

### Final Snapshot

```hcl
skip_final_snapshot = true
```

Terraform is allowed to delete the database without creating a final RDS snapshot.

This behavior is intentional for the portfolio environment because the database contains no production data and the environment is routinely destroyed after validation to avoid unnecessary AWS charges.

For production workloads, a final snapshot should normally be created before database deletion unless an approved data-retention policy specifies otherwise.

### Production Hardening Considerations

If this architecture were adapted for production use, the RDS lifecycle configuration should be reviewed and could include:

- Enabling deletion protection.
- Increasing automated backup retention.
- Creating a final snapshot before database deletion.
- Defining formal recovery point and recovery time objectives.
- Applying database snapshot retention and lifecycle policies.
- Testing backup restoration procedures regularly.

The staged RDS configuration therefore represents a deliberate lab-environment tradeoff and should not be interpreted as the recommended deletion or backup posture for a production database.

---
## 14. Environment Teardown

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

Verify all applicable cost-generating resources, including resources that may have been deployed separately from the active Terraform root:

- RDS instances
- EC2 instances
- NAT Gateways
- Elastic IP addresses
- CloudWatch resources
- Secrets Manager secrets
- Other resources that may generate ongoing charges

Some AWS resources may have retention or deletion behavior that requires additional verification. Resources created manually, resources managed by a different Terraform root or state, and staged resources deployed separately may require independent cleanup and should be verified after `terraform destroy`.

---

## 15. Redeployment

The environment can be recreated from the Terraform configuration when additional testing or validation is required.

The normal redeployment sequence is:

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

This sequence redeploys the infrastructure defined in the active `terraform/` root. Resources retained under `future/` are not included unless those configurations are intentionally integrated or deployed separately.

If Terraform has already been initialized and the provider/backend configuration has not changed, another initialization may not always be necessary. Running `terraform init` again is safe and can confirm that the working directory is properly initialized.

After redeployment:

1. Review Terraform outputs.
2. Validate the resources in AWS.
3. Configure required secret values when staged Secrets Manager resources are deployed.
4. Validate applicable security controls.
5. Validate monitoring when the staged monitoring configuration is deployed.
6. Perform the intended testing.
7. Destroy unnecessary cost-generating resources after testing.

---

## 16. Cost Considerations

Cost control was an explicit design consideration throughout the project.

The architecture includes AWS services that may generate charges even when resource utilization is low.

Cost-sensitive components represented by the active or staged architecture include:

- NAT Gateway
- EC2
- Amazon RDS
- Elastic IP addresses
- Secrets Manager
- CloudWatch
- Data transfer

The project therefore uses several cost-control practices:

- Avoid maintaining a NAT Gateway when it is not required.
- Avoid maintaining an EC2 bastion host when it is not required.
- Destroy RDS instances after validation.
- Review Terraform plans before deployment.
- Destroy temporary infrastructure after testing.
- Verify resource removal through the AWS Management Console.
- Avoid assuming that all AWS services are covered by the AWS Free Tier.

Cost optimization is treated as an operational requirement rather than an afterthought.

---

## 17. Security Considerations

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

The staged RDS PostgreSQL configuration is designed to operate in private subnets with public accessibility disabled.

### Encryption

The staged RDS configuration enables database storage encryption to protect RDS data at rest when that configuration is deployed.

### Secrets Management

The staged hardening design uses AWS Secrets Manager for sensitive database credentials rather than storing them in Terraform source code or committing them to source control.

### IAM Least Privilege

AWS identities and resources should receive only the permissions required to perform their intended functions.

### Terraform Security

The following should never be committed to GitHub:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
tfplan
*.tfplan
crash.log
crash.*.log
AWS credentials
Private SSH keys
Database passwords
Secret values
```

The repository `.gitignore` should be reviewed before publishing the project.

---

## 18. Troubleshooting References

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

- AWS authentication failures
- IAM permission errors
- Incorrect Terraform variables
- Resource dependency problems
- Security Group rules
- NACL rules
- Route table associations
- Subnet configuration
- RDS deployment failures
- CloudWatch configuration
- Secrets Manager access

Detailed problems encountered while building the environment and their resolutions are documented separately in:

```text
docs/troubleshooting-guide.md
```
