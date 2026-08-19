# Phase 10 – Enterprise Security Hardening

## 1. Purpose

The purpose of this phase was to strengthen the AWS networking and database environment by introducing production-style security controls around database credentials and access to sensitive configuration data.

Earlier phases established the network architecture, security boundaries, RDS PostgreSQL deployment, and CloudWatch monitoring. Phase 10 builds on that foundation by defining a staged AWS Secrets Manager and IAM least-privilege architecture for database credential management. The configuration is retained under `future/` and is not part of the currently deployed networking baseline.

The broader production-hardening areas considered for the environment include:

* Secrets management
* IAM least-privilege access
* Encryption
* Logging and auditing
* Compliance controls
* Cost controls
* Operational documentation

The staged implementation in this phase focuses specifically on Secrets Manager integration and least-privilege IAM access.

**Current Repository State:** The Phase 10 Secrets Manager, IAM, and RDS credential-integration resources are retained as staged Terraform configuration under `future/`. These resources are not currently deployed. The Phase 08 RDS instance was previously deployed and validated, then destroyed to avoid ongoing AWS charges.

---

## 2. Objectives

The objectives for this phase were to:

1. Define an AWS Secrets Manager secret for the RDS PostgreSQL administrator credentials.
2. Define a pattern for storing the actual database credentials separately from Terraform configuration files.
3. Define Terraform data sources for retrieving the secret.
4. Define Terraform local values for decoding the stored JSON secret.
5. Define the intended RDS PostgreSQL integration for consuming the retrieved credentials.
6. Define an IAM policy granting only the permissions required to retrieve the database secret.
7. Establish a pattern for attaching secret access only to authorized application or compute roles.
8. Document Terraform and AWS validation procedures for a future deployment.
9. Document additional production-hardening controls for future implementation.

---

## 3. Architecture Overview

Phase 10 introduces AWS Secrets Manager between the application/infrastructure layer and the database credentials.

The intended security model is:

The following diagram represents the intended Phase 10 security architecture when the staged RDS and Secrets Manager configuration is integrated and deployed.

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

This architecture is designed to reduce reliance on plaintext database passwords stored directly in Terraform variable files and provides a centralized AWS service for managing sensitive credentials.

---

# 4. Implementation

## 4.1 Create the Secrets Manager Configuration

During Phase 10 development, Secrets Manager configuration was separated into a dedicated Terraform file. In the reconciled repository, this configuration is retained as `future/secrets.tf`.

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

The staged configuration creates both the Secrets Manager secret container and a Terraform-managed secret version. The secret version stores the database username and password as JSON using the staged database credential variables.

Although this removes the credentials from ordinary resource arguments and centralizes them in AWS Secrets Manager, Terraform still handles the sensitive values during deployment and may retain them in Terraform state.

---

## 4.2 Create the Secret Version

The staged Terraform configuration also defines a Secrets Manager secret version in `future/secrets.tf`.

The secret version stores the database username and password as a JSON-formatted value:

```hcl
resource "aws_secretsmanager_secret_version" "rds_postgres_admin" {
  secret_id = aws_secretsmanager_secret.rds_postgres_admin.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}
```

`jsonencode()` stores the username and password as a JSON-formatted secret value in AWS Secrets Manager.

The sensitive values are still supplied to Terraform through `var.db_username` and `var.db_password`. Therefore, this pattern centralizes runtime credential storage in Secrets Manager but does not eliminate Terraform's exposure to the credential values.

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

Terraform data sources for the staged Secrets Manager integration are retained in `future/data_secrets.tf`.

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

The RDS-specific local values used by the staged credential integration are retained in `future/locals_rds.tf`.

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

The staged RDS configuration in `future/rds.tf` is designed to reference credential values retrieved through the Secrets Manager integration.

```hcl
resource "aws_db_instance" "postgres" {
  # Existing RDS configuration...

  username = local.rds_admin_username
  password = local.rds_admin_password
}
```

This changes how the staged RDS resource consumes the database credentials. Rather than referencing the credential variables directly, the RDS resource consumes values retrieved from Secrets Manager and decoded into Terraform local values.

This pattern centralizes the database credential in AWS Secrets Manager and allows the staged RDS configuration to consume the secret through a consistent AWS-managed credential location. Because Terraform still receives and handles the credential values in this implementation, the Terraform input path and state must continue to be treated as sensitive.

---

# 5. IAM Least-Privilege Access

## 5.1 Create the Secret Access Policy

The staged least-privilege IAM policy is retained in `future/iam_secrets_access.tf`.

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

No workload-role attachment should be described as currently deployed unless a corresponding IAM role and policy attachment exist in the active or staged Terraform source.

---

# 6. Deployment

The commands in this section describe the workflow that would be used when integrating and deploying the staged Phase 10 configuration. The Secrets Manager, IAM, and associated RDS credential-integration resources are not currently deployed.

**Important:** The files under `future/` are retained as staged infrastructure configuration and are not intended to be deployed as an independent Terraform root module in their current repository location. Before deploying Phase 10, the required Secrets Manager, IAM, RDS, variables, data sources, and local-value configuration must be integrated into the active Terraform root configuration under `terraform/`, or assembled into another complete Terraform root module with all required dependencies and provider configuration.

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

The integrated configuration must ensure that the Secrets Manager secret contains a current secret version before Terraform attempts to retrieve and consume that value for the RDS configuration. The Terraform dependency graph should be reviewed during integration to confirm the required ordering between the secret, secret version, data sources, local values, and RDS resource.

---

# 7. Validation

The following procedures document how the staged Phase 10 resources should be validated when they are deployed.

## 7.1 Terraform Validation

The following commands should be used:

```powershell
terraform fmt
terraform validate
terraform plan
```

Expected results:

* Terraform files are properly formatted.
* Terraform configuration passes syntax and dependency validation.
* The execution plan contains only the expected infrastructure changes.
* No database password is hard-coded in tracked Terraform source files or committed repository content.

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
The Phase 10 design strengthens the intended security architecture by moving toward AWS-native credential management and least-privilege secret access.

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

When the staged RDS configuration is deployed, PostgreSQL remains designed to operate in private subnets, protected by the database security group and without direct public accessibility.

Secrets Manager does not replace network-level security controls. It complements them by protecting credential storage and access.

### Encryption

The RDS PostgreSQL instance was configured with storage encryption during the RDS deployment phase.

AWS Secrets Manager also encrypts secret values at rest.

For a more advanced production environment, customer-managed AWS KMS keys could be introduced to provide additional control over encryption key permissions and lifecycle management.

### Terraform State Consideration

Although Secrets Manager removes the password from normal Terraform configuration files, retrieving the secret through Terraform and passing it into the RDS `password` argument can still expose sensitive information to **Terraform state**.

Therefore, Terraform state must be treated as sensitive infrastructure data. Access to state should be restricted regardless of backend type.

If the project is later migrated to an Amazon S3 remote-state backend, appropriate controls should include:

- Restricted IAM access.
- S3 encryption.
- S3 Block Public Access.
- State locking using the selected backend mechanism, where applicable.
- Controlled administrative access.

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

Verify that `future/secrets.tf` includes `aws_secretsmanager_secret_version.rds_postgres_admin` and that the required credential variables are supplied to Terraform.

Confirm that the secret-version resource is included in the same integrated Terraform configuration as the data source that retrieves the current secret value.

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

Verify that the integrated Terraform configuration includes:

1. `aws_secretsmanager_secret.rds_postgres_admin`.
2. `aws_secretsmanager_secret_version.rds_postgres_admin`.
3. `data.aws_secretsmanager_secret.rds_postgres_admin`.
4. `data.aws_secretsmanager_secret_version.rds_postgres_admin_current`.
5. The RDS-specific local values defined in `future/locals_rds.tf`.
6. The RDS credential references in `future/rds.tf`.

Also verify that the required `db_username` and `db_password` variable values are supplied securely before planning or applying the staged configuration.

Terraform should then be able to establish the required dependency relationships between the secret, secret version, retrieved secret data, local values, and RDS instance.

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

Phase 10 defined and retained a staged enterprise-hardening design that includes:

- AWS Secrets Manager configuration for RDS PostgreSQL administrator credentials.
- A pattern for separating database credentials from ordinary Terraform variable files.
- Terraform data-source and local-value integration for Secrets Manager.
- A least-privilege IAM policy for secret retrieval.
- A controlled model for future workload-role attachment.
- Future deployment and validation procedures.
- A roadmap for additional logging, compliance, encryption, and cost-management controls.

Phase 10 demonstrates how credential management and least-privilege IAM controls can be incorporated into a Terraform-managed AWS architecture while clearly separating staged security-hardening configuration from the project's currently active networking baseline.
