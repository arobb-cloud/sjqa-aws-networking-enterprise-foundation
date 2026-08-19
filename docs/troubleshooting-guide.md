# Troubleshooting Guide

## Purpose

This guide documents common Terraform, AWS authentication, networking, and deployment issues that may occur while working with the AWS Enterprise Networking Foundation project.

The troubleshooting procedures reflect the current repository structure, where core networking resources are managed from the `terraform/` directory, optional NAT Gateway and bastion resources are disabled by default, and additional database, monitoring, and hardening configurations are retained under `future/`.

---

## 1. Terraform Initialization Issues

### Symptoms

Terraform commands may fail because required providers or modules have not been initialized.

Typical errors may reference:

* Missing provider plugins
* Provider dependency inconsistencies
* An uninitialized working directory
* Missing `.terraform` files

### Resolution

From the `terraform/` directory, run:

```powershell
terraform init
```

Then validate the configuration:

```powershell
terraform validate
```

If provider dependencies have intentionally changed, review the dependency lock file before performing any provider upgrade.

---

## 2. AWS Authentication Issues

### Symptoms

Terraform may fail when attempting to communicate with AWS.

Authentication errors can include:

```text
InvalidClientTokenId
```

or:

```text
The security token included in the request is invalid
```

### Resolution

Verify the active AWS identity:

```powershell
aws sts get-caller-identity
```

Confirm that the AWS CLI is using the intended credentials and that the associated access key or temporary credentials are valid.

If environment variables are being used, verify that stale AWS credential variables are not overriding the expected AWS CLI configuration.

After correcting authentication, run:

```powershell
terraform plan
```

to confirm Terraform can communicate successfully with AWS.

---

## 3. Terraform Validation or Formatting Errors

Before planning infrastructure changes, run:

```powershell
terraform fmt -check
terraform validate
```

If formatting problems are detected, run:

```powershell
terraform fmt
```

Then repeat validation.

Terraform validation errors should be corrected before running `terraform plan` or `terraform apply`.

---

## 4. VPC and Subnet Configuration Issues

The project uses a custom VPC with separate public and private subnets distributed across two Availability Zones.

When troubleshooting subnet problems, verify:

* Subnet CIDR blocks do not overlap.
* Each subnet belongs to the expected VPC.
* Public and private subnets are associated with the correct route tables.
* Availability Zone assignments match the intended multi-AZ architecture.
* Public IP behavior is appropriate for the subnet tier.

The current subnet layout is:

| Subnet    | CIDR           | Tier    |
| --------- | -------------- | ------- |
| Public A  | `10.22.1.0/24` | Public  |
| Public B  | `10.22.2.0/24` | Public  |
| Private A | `10.22.11.0/24` | Private |
| Private B | `10.22.12.0/24` | Private |

---

## 5. Routing Issues

### Public Subnets

Public subnet Internet connectivity depends on:

1. An Internet Gateway attached to the VPC.
2. A default route for `0.0.0.0/0` pointing to the Internet Gateway.
3. Correct association between the public subnets and public route table.
4. Security group and Network ACL rules permitting the required traffic.

### Private Subnets

Private subnets do not have direct Internet Gateway routing.

The repository contains optional NAT Gateway configuration that can provide outbound Internet connectivity for private resources. NAT deployment is disabled by default to avoid unnecessary AWS charges.

If NAT connectivity is intentionally enabled, verify:

* The NAT Gateway feature variable is enabled.
* The Elastic IP is created successfully.
* The NAT Gateway is deployed in the expected public subnet.
* The private route table contains a `0.0.0.0/0` route through the NAT Gateway.
* The NAT Gateway has reached an available state.

Do not assume that private subnet Internet connectivity exists when the NAT Gateway is disabled.

---

## 6. Security Group Issues

The project defines security groups for separate infrastructure tiers:

* Application
* Database
* Management

When troubleshooting connectivity, verify:

* The source and destination security groups.
* The required TCP port.
* Inbound rules on the destination resource.
* Outbound rules on the source resource.
* CIDR restrictions where applicable.

Security groups are stateful, so return traffic for an allowed connection does not require a separate inbound rule.

---

## 7. Network ACL Issues

Network ACLs provide subnet-level controls for the public and private network tiers.

When troubleshooting NACL-related connectivity, verify:

* The subnet is associated with the expected NACL.
* Both inbound and outbound rules permit the required traffic.
* Rule numbers are evaluated in the intended order.
* Ephemeral port ranges required for return traffic are permitted.
* Application-to-database traffic uses the expected port and network path.

Unlike security groups, Network ACLs are stateless. Required return traffic must therefore be explicitly permitted.

---

## 8. Optional NAT Gateway Issues

The NAT Gateway configuration is present in the active Terraform configuration but is disabled by default.

Before troubleshooting a missing NAT Gateway, verify whether it is supposed to exist.

Review the configured value for:

```hcl
enable_nat_gateway
```

If the value is `false`, Terraform intentionally does not create the NAT Gateway, Elastic IP, or NAT-dependent private route.

This is expected behavior rather than a deployment failure.

---

## 9. Optional Bastion Host Issues

The bastion host configuration is also disabled by default.

Before troubleshooting a missing bastion instance, verify:

```hcl
enable_bastion
```

If bastion deployment is intentionally enabled, also verify:

* A valid EC2 key pair name has been supplied.
* The allowed management CIDR is correctly configured.
* The management security group permits the intended SSH traffic.
* The bastion is placed in the expected public subnet.
* The selected AMI is available in the configured AWS Region.

A missing bastion host is expected when the feature is disabled.

---

## 10. Future / Staged Resource Issues

Database, monitoring, secrets-management, and related hardening configurations are retained under the repository's `future/` directory.

These files should not be interpreted as part of the currently active Terraform deployment simply because Terraform configuration exists for them.

Examples include staged configuration for:

* Amazon RDS PostgreSQL
* Amazon CloudWatch RDS alarms
* Amazon SNS alerting
* AWS Secrets Manager
* IAM integration for secrets access

Troubleshooting the active networking environment should first focus on resources defined under `terraform/`.

---

## 11. Terraform State and Plan Files

Terraform state and generated plan files should remain local and must not be committed to the repository.

Examples include:

```text
terraform.tfstate
terraform.tfstate.backup
tfplan
destroy.tfplan
.terraform/
```

If unexpected infrastructure behavior occurs, verify that Terraform is operating against the intended state before applying changes.

Do not manually edit Terraform state files unless performing a deliberate and well-understood state recovery procedure.

---

## 12. Recommended Troubleshooting Workflow

When Terraform or AWS networking behavior is unexpected, use the following sequence:

```text
Verify AWS Credentials
        │
        ▼
terraform fmt -check
        │
        ▼
terraform validate
        │
        ▼
terraform plan
        │
        ▼
Review Planned Resources
        │
        ▼
Verify Feature Flags
        │
        ▼
Review VPC / Routes / SGs / NACLs
        │
        ▼
Apply Only When Expected
```

This workflow helps distinguish configuration problems from expected behavior caused by optional resources being intentionally disabled.

---

## Future Troubleshooting Coverage

Additional troubleshooting procedures can be added if staged capabilities are integrated into the active Terraform deployment, including:

* RDS PostgreSQL connectivity
* CloudWatch alarms and SNS notifications
* Secrets Manager integration
* VPC Flow Logs
* VPC endpoints
* Additional private-service connectivity
