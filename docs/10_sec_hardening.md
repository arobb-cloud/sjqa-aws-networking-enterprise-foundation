#Phase 10 – Enterprise Security Hardening

## 1. Purpose

The purpose of this phase was to strengthen the AWS networking and database environment by introducing production-style security controls around database credentials and access to sensitive configuration data.

Earlier phases established the network architecture, security boundaries, RDS PostgreSQL deployment, and CloudWatch monitoring. Phase 10 builds on that foundation by removing database administrator credentials from the Terraform variable workflow and introducing AWS Secrets Manager and IAM least-privilege access controls.

The broader production-hardening areas considered for the environment include:

* Secrets management
* IAM least-privilege access
* Encryption
* Logging and auditing
* Compliance controls
* Cost controls
* Operational documentation

The implementation in this phase focuses specifically on **Secrets Manager integration and least-privilege IAM access**.

---

## 2. Objectives

The objectives for this phase were to:

1. Create an AWS Secrets Manager secret for the RDS PostgreSQL administrator credentials.
2. Store the actual database credentials separately from Terraform configuration files.
3. Retrieve the secret through Terraform data sources.
4. Decode the stored JSON secret into Terraform local values.
5. Configure the RDS PostgreSQL instance to consume the retrieved credentials.
6. Define an IAM policy granting only the permissions required to retrieve the database secret.
7. Establish a pattern for attaching secret access only to authorized application or compute roles.
8. Validate the Terraform configuration and confirm creation of the secret through the AWS CLI.
9. Document additional production-hardening controls for future implementation.

---

## 3. Architecture Overview

Phase 10 introduces AWS Secrets Manager between the application/infrastructure layer and the database credentials.

The intended security model is:

```text
                    AWS Account
                        │
                        ▼
               ┌─────────────────┐
               │ IAM Role/Policy │
               │ Least Privilege │
               └────────┬────────┘
                        │
                        │ GetSecretValue
                        ▼
              ┌──────────────────────┐
              │ AWS Secrets Manager  │
              │                      │
              │ PostgreSQL Admin     │
              │ Credentials          │
              └──────────┬───────────┘
                         │
                         │ Credentials
                         ▼
              ┌──────────────────────┐
              │ Terraform / RDS      │
              │ Configuration        │
              └──────────┬───────────┘
                         │
                         ▼
                 Private Subnets
                         │
              ┌──────────────────────┐
              │ Amazon RDS           │
              │ PostgreSQL           │
              │ Private Access Only  │
              └──────────────────────┘
```

This architecture reduces reliance on plaintext database passwords stored directly in Terraform variable files and provides a centralized AWS service for managing sensitive credentials.

---

# 4. Implementation

## 4.1 Create the Secrets Manager Configuration

A new Terraform file was created:

```powershell
New-Item secrets.tf
```

The following resource defines the Secrets Manager secret container:

```hcl
resource "aws_secretsmanager_secret" "rds_postgres_admin" {
  name        = "${var.project_name}-${var.environment}-rds-postgres-admin"
  description = "Admin credentials for RDS PostgreSQL"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Compliance  = "Phase-10-Enterprise-Hardening"
  }
}
```

This resource creates the Secrets Manager object but does not place the actual username or password inside the Terraform configuration.

The separation is intentional. Terraform manages the secret resource while the sensitive credential value is inserted separately.

---

## 4.2 Populate the Secret Manually

The secret value was designed to be populated outside the Terraform configuration using the AWS CLI.

Example:

```powershell
aws secretsmanager put-secret-value `
  --secret-id <secret-name-or-arn> `
  --secret-string '{"username":"postgres_admin","password":"REPLACE_WITH_STRONG_PASSWORD"}'
```

The secret uses JSON so that the username and password can be retrieved independently:

```json
{
  "username": "postgres_admin",
  "password": "REPLACE_WITH_STRONG_PASSWORD"
}
```

The real password should never be included in project documentation, screenshots, Git repositories, or example Terraform files.

---

## 4.3 Retrieve the Secret with Terraform

A new Terraform file was created:

```powershell
New-Item data_secrets.tf
```

The following data sources retrieve the secret and its current value:

```hcl
data "aws_secretsmanager_secret" "rds_postgres_admin" {
  name = aws_secretsmanager_secret.rds_postgres_admin.name
}

data "aws_secretsmanager_secret_version" "rds_postgres_admin_current" {
  secret_id = data.aws_secretsmanager_secret.rds_postgres_admin.id
}
```

The first data source identifies the Secrets Manager secret.

The second retrieves the current version containing the credential JSON.

---

## 4.4 Decode the Secret

The following values were added to `locals.tf` when preparing the RDS deployment:

```hcl
locals {
  rds_admin_secret = jsondecode(
    data.aws_secretsmanager_secret_version.rds_postgres_admin_current.secret_string
  )

  rds_admin_username = local.rds_admin_secret["username"]
  rds_admin_password = local.rds_admin_secret["password"]
}
```

`jsondecode()` converts the JSON secret into a Terraform object.

Terraform can then reference the individual values through:

```hcl
local.rds_admin_username
local.rds_admin_password
```

### Deployment Note

These local values should only be introduced when the corresponding secret value exists and the RDS resource is ready to consume it.

Otherwise, Terraform may attempt to retrieve a secret version that has not yet been populated.

---

## 4.5 Update the RDS PostgreSQL Configuration

The existing `rds.tf` configuration was updated so that the database administrator credentials reference the values retrieved from Secrets Manager.

```hcl
resource "aws_db_instance" "postgres" {
  # Existing RDS configuration...

  username = local.rds_admin_username
  password = local.rds_admin_password
}
```

This replaces the previous pattern where the database password was supplied directly through a Terraform variable such as:

```hcl
db_password = "..."
```

The change improves credential management by separating the database password from the normal Terraform configuration and `terraform.tfvars` workflow.

---

# 5. IAM Least-Privilege Access

## 5.1 Create the Secret Access Policy

A new Terraform file was created:

```powershell
New-Item iam_secrets_access.tf
```

The following IAM policy grants only the permissions necessary to retrieve and inspect the RDS administrator secret:

```hcl
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
```

The policy does not grant broad Secrets Manager permissions.

Instead, access is restricted to:

```text
secretsmanager:GetSecretValue
secretsmanager:DescribeSecret
```

and only for the specific RDS PostgreSQL secret created by this project.

---

## 5.2 Attach the Policy to an Authorized Role

The policy should only be attached to an IAM role that has a legitimate requirement to retrieve the database credentials.

For example:

```hcl
resource "aws_iam_role_policy_attachment" "app_read_rds_secret" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.read_rds_secret.arn
}
```

`aws_iam_role.app_role` is an example placeholder.

In a production environment, this could instead represent an:

* EC2 instance role
* ECS task role
* Lambda execution role
* Application service role

The policy should not be attached to unrelated users, services, or administrative roles.

---

# 6. Deployment

Before deployment, the Terraform configuration was formatted and validated.

```powershell
terraform fmt
terraform validate
terraform plan
```

The execution plan should be reviewed before applying the configuration.

If the planned resources and changes are correct:

```powershell
terraform apply
```

The Secrets Manager secret must contain a valid secret version before Terraform attempts to retrieve the credential values for the RDS deployment.

---

# 7. Validation

Validation was performed at both the Terraform and AWS service levels.

## 7.1 Terraform Validation

The following commands were used:

```powershell
terraform fmt
terraform validate
terraform plan
```

Expected results:

* Terraform files are properly formatted.
* Terraform configuration passes syntax and dependency validation.
* The execution plan contains only the expected infrastructure changes.
* No plaintext database password appears in the Terraform configuration.

---

## 7.2 AWS CLI Validation

The secret configuration can be confirmed with:

```powershell
aws secretsmanager describe-secret `
  --secret-id <secret-name>
```

This verifies that the secret exists and allows metadata to be inspected without displaying the secret value.

The secret value itself should not be displayed or captured in project documentation.

---

## 7.3 AWS Console Validation

The configuration can also be verified from:

**AWS Console → Secrets Manager → Secrets**

Confirm that:

* The RDS PostgreSQL administrator secret exists.
* The expected project and environment tags are present.
* The secret contains a current version.
* The secret metadata corresponds to the Terraform-managed resource.

IAM validation can be performed from:

**AWS Console → IAM → Policies**

Confirm that:

* The RDS secret read policy exists.
* `GetSecretValue` and `DescribeSecret` are the only required Secrets Manager actions.
* The policy resource is restricted to the specific secret ARN.
* The policy is attached only to an authorized workload role when such a role exists.

---

# 8. Security Considerations
Phase 10 strengthens the security architecture by moving database credential management away from plaintext Terraform variables and toward AWS-native secret management.

### Credential Management

Database credentials should not be committed to:

```text
terraform.tfvars
*.tf files
README files
Git repositories
screenshots
terminal transcripts
```

AWS Secrets Manager provides a centralized location for storing and controlling access to sensitive credentials.

### Least-Privilege IAM

Secret access should be granted only to identities that require it.

The IAM policy therefore:

1. Allows only the required Secrets Manager read operations.
2. Restricts access to the specific RDS PostgreSQL secret ARN.
3. Avoids wildcard resource permissions.
4. Can be attached only to the workload role requiring database credentials.

### Network Security

The security controls established in earlier phases remain in effect.

The RDS PostgreSQL database remains:

* Located in private subnets.
* Protected by the database security group.
* Unavailable through direct public access.
* Reachable only through explicitly authorized network paths.

Secrets Manager does not replace network-level security controls. It complements them by protecting credential storage and access.

### Encryption

The RDS PostgreSQL instance was configured with storage encryption during the RDS deployment phase.

AWS Secrets Manager also encrypts secret values at rest.

For a more advanced production environment, customer-managed AWS KMS keys could be introduced to provide additional control over encryption key permissions and lifecycle management.

### Terraform State Consideration

Although Secrets Manager removes the password from normal Terraform configuration files, retrieving the secret through Terraform and passing it into the RDS `password` argument can still expose sensitive information to **Terraform state**.

Therefore, the Terraform state backend itself must be treated as sensitive infrastructure data and protected through:

* Restricted IAM access.
* S3 encryption.
* S3 public access blocking.
* State locking where appropriate.
* Controlled administrative access.

Removing a password from `terraform.tfvars` does not by itself guarantee that Terraform never handles or stores the credential.

---

# 9. Production Hardening Considerations

Phase 10 establishes an initial enterprise-hardening pattern, but a fully production-ready AWS environment would require additional controls.

These include:

### Secrets Management

* Automated secret rotation.
* Application-level secret retrieval.
* Credential lifecycle procedures.
* Secret recovery and deletion policies.

### IAM

* Dedicated workload roles.
* Permission boundaries where appropriate.
* Periodic access reviews.
* Elimination of unnecessary wildcard permissions.

### Encryption

* Customer-managed KMS keys where required.
* Explicit key policies.
* Key rotation.
* Encryption controls for logs, state, backups, and snapshots.

### Logging and Auditing

* CloudTrail auditing.
* CloudWatch log retention policies.
* RDS PostgreSQL log exports.
* IAM activity monitoring.
* Secrets Manager API activity monitoring.

### Compliance

* AWS Config rules.
* Security Hub.
* Resource tagging standards.
* Configuration drift detection.
* Periodic security assessments.

### Cost Controls

* AWS Budgets.
* Cost allocation tags.
* Billing alarms.
* Removal of unused infrastructure.
* Environment-specific resource sizing.

These controls were identified as logical extensions of the architecture but should be documented as **future hardening opportunities unless they were explicitly deployed during this phase**.

---

# 10. Troubleshooting

## Secret Version Does Not Exist

### Issue

Terraform can locate the Secrets Manager secret but fails when retrieving:

```hcl
data.aws_secretsmanager_secret_version.rds_postgres_admin_current
```

### Cause

Creating:

```hcl
aws_secretsmanager_secret
```

creates the secret container but does not automatically create the username/password secret value.

### Resolution

Populate the secret before attempting to retrieve the current version:

```powershell
aws secretsmanager put-secret-value `
  --secret-id <secret-name-or-arn> `
  --secret-string '{"username":"postgres_admin","password":"REPLACE_WITH_STRONG_PASSWORD"}'
```

---

## AccessDeniedException

### Issue

An application or AWS workload cannot retrieve the secret.

### Possible Cause

The workload IAM role does not have permission to perform:

```text
secretsmanager:GetSecretValue
```

### Resolution

Verify that the least-privilege policy is attached to the correct IAM role and that the policy references the correct secret ARN.

---

## Terraform Dependency Issues

### Issue

Terraform attempts to retrieve the secret value before a secret version exists.

### Resolution

Use a staged deployment process:

1. Create the Secrets Manager secret.
2. Populate the secret value.
3. Introduce or enable the Terraform data source that retrieves the secret version.
4. Deploy the RDS configuration that consumes the credentials.

This prevents Terraform from attempting to read a secret value that has not yet been created.

---

# 11. Lessons Learned

This phase demonstrated that production hardening is not a single AWS service or configuration change. It is a collection of security and operational controls applied across identity, credentials, networking, encryption, monitoring, and infrastructure management.

Key lessons include:

1. Sensitive credentials should be separated from normal Terraform configuration and source control.
2. Creating a Secrets Manager secret and creating its secret value are separate operations.
3. IAM permissions should grant only the actions and resources required by a workload.
4. Secrets Manager complements rather than replaces security groups, NACLs, private subnets, and other network controls.
5. Terraform state must be treated as sensitive because secret values consumed by Terraform may still be represented in state.
6. Production hardening should be implemented incrementally so that each security control can be independently validated.
7. Controls that were evaluated but not deployed should be clearly documented as future enhancements rather than represented as completed implementation.

---

# 12. Phase Outcome

Phase 10 extended the AWS networking project from infrastructure deployment toward a more production-oriented security architecture.

The phase established:

* AWS Secrets Manager for RDS PostgreSQL administrator credentials.
* Separation of database passwords from normal Terraform variable files.
* Terraform integration with Secrets Manager.
* Least-privilege IAM policy design for secret retrieval.
* A controlled model for attaching secret access to authorized workloads.
* Security validation procedures.
* A roadmap for additional logging, compliance, encryption, and cost-management controls.

With Phase 10, the project demonstrates not only how AWS infrastructure can be provisioned with Terraform, but also how credential management and IAM controls can be incorporated into the infrastructure lifecycle using production-oriented security principles.
