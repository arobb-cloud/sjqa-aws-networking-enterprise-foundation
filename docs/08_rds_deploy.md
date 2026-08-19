# Phase 08 – Amazon RDS PostgreSQL Deployment

## 1. Purpose

The purpose of this phase was to deploy and validate an Amazon RDS for PostgreSQL database within the private database tier of the VPC.

This phase built on the networking and security controls implemented during the previous phases by placing the database within the existing private subnets and associating it with the previously created database security group.

The RDS PostgreSQL environment was successfully deployed and validated during project development and was later destroyed to avoid ongoing AWS charges. The validated RDS Terraform configuration is now retained under the repository's `future/` directory for future integration and is not part of the currently deployed networking baseline.

The deployment was designed to demonstrate a production-inspired private database architecture while remaining suitable for a temporary training and portfolio environment.

The resulting traffic pattern is:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public / Application Tier
   │
   │  Authorized application access
   │  PostgreSQL TCP/5432
   ▼
Database Security Group
   │
   │  PostgreSQL TCP/5432
   ▼
Private Subnets
   │
   ▼
Amazon RDS PostgreSQL
```

The RDS database itself does not receive a public IP address and is not directly accessible from the Internet.

---

## 2. Objectives

The objectives for this phase were to:

1. Deploy Amazon RDS for PostgreSQL.
2. Place the database within the existing private subnets.
3. Create an RDS DB subnet group spanning both private Availability Zones.
4. Create a PostgreSQL parameter group.
5. Associate the RDS instance with the existing database security group.
6. Disable public database accessibility.
7. Enable storage encryption.
8. Configure automated backup retention.
9. Protect database credentials from being committed to GitHub.
10. Expose database connection information through Terraform outputs.
11. Validate the Terraform configuration before deployment.
12. Deploy and verify the RDS resources in AWS.
13. Destroy the temporary RDS resources after validation to prevent continued AWS charges while retaining the validated Terraform configuration for future reuse.

---

## 3. Architecture

Phase 08 extends the existing Multi-AZ network architecture by introducing a managed PostgreSQL database tier.

Current Repository State: The architecture below represents the RDS environment that was deployed and validated during Phase 08. The RDS instance is no longer running. Its Terraform configuration is retained under `future/` as staged infrastructure.

```text
                         Internet
                            │
                            ▼
                    Internet Gateway
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       Public Subnet A              Public Subnet B
         us-east-1a                   us-east-1b
              │                           │
              └─────────────┬─────────────┘
                            │
                 Authorized Application
                    Access Pattern
                            │
                            ▼
                  Database Security Group
                     PostgreSQL 5432
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
      Private Subnet A             Private Subnet B
        us-east-1a                   us-east-1b
              │                           │
              └─────────────┬─────────────┘
                            │
                    RDS Subnet Group
                            │
                            ▼
                 Amazon RDS PostgreSQL
                  Public Access: False
                  Storage: Encrypted
                  Backups: Enabled
```

Although the DB subnet group spans private subnets in two Availability Zones, the RDS instance itself was configured with:

```hcl
multi_az = false
```

Therefore, this phase provides **Multi-AZ subnet placement capability**, but it does not deploy a Multi-AZ RDS database instance.

This distinction is important: the subnet group gives RDS eligible subnets across Availability Zones, while `multi_az = true` would be required to provision a standby database instance for Multi-AZ high availability.

---

## 4. Implementation

### 4.1 Create RDS Variables

During development, database-specific variables were introduced to support the RDS deployment. In the reconciled repository, RDS-specific variable definitions are retained with the staged database configuration under:

`future/variables_rds.tf`

This separation keeps the currently active networking baseline under `terraform/` distinct from database resources that were previously validated but are not currently deployed.

```hcl
variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for PostgreSQL"
  type        = string
  sensitive   = true
}
```

These variables separate database-specific configuration from the RDS resource definition.

The `sensitive = true` setting prevents Terraform from displaying the database password in normal CLI output. However, marking a Terraform variable as sensitive does **not** prevent the value from being stored in Terraform state.

---

### 4.2 Configure the Database Password

For the training deployment, the database password was supplied locally through `terraform.tfvars`:

```hcl
db_password = "<local-training-password>"
```

The actual password should not be included in project documentation or committed to source control.

For this project, `terraform.tfvars` remained local to the workstation.

> **Security Note:** The original training deployment used a locally supplied `terraform.tfvars` value that remained outside source control. The project was later extended with staged AWS Secrets Manager and IAM configuration under `future/` to demonstrate a stronger credential-management model. Those resources are retained for future integration and are not currently deployed.

---

### 4.3 Verify Git Exclusions

The `.gitignore` configuration was verified to prevent Terraform variable files and plan files from being committed:

```gitignore
*.tfvars
terraform.tfvars
tfplan
*.tfplan
```

This reduces the risk of accidentally exposing database credentials through the GitHub repository.

The repository should also be checked with:

```powershell
git status
```

before each commit to verify that `terraform.tfvars` is not staged or tracked.

---

### 4.4 Create the RDS Subnet Group

The RDS resources that were previously deployed and validated are now retained in:

```text
future/rds.tf
```

Moving the configuration under `future/` preserves the validated implementation while preventing the repository structure from implying that RDS is part of the currently active networking deployment.

The following DB subnet group was added:

```hcl
resource "aws_db_subnet_group" "postgres" {
  name = "${var.project_name}-${var.environment}-postgres-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres-subnet-group"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The subnet group places the RDS service within the private database network and provides eligible subnets across both configured Availability Zones.

The subnet group does not make the RDS instance Multi-AZ by itself. It defines where RDS is permitted to place database resources.

---

### 4.5 Create the PostgreSQL Parameter Group

A custom PostgreSQL 16 parameter group was created:

```hcl
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-${var.environment}-postgres-parameter-group"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres-parameter-group"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The parameter group enables logging of PostgreSQL connection and disconnection events.

This provides a foundation for future database observability and monitoring work.

---

### 4.6 Create the RDS PostgreSQL Instance

The PostgreSQL RDS instance used during the original Phase 08 deployment was defined as shown below. The credential arguments preserve the Phase 08 implementation used during deployment and validation. The current staged version under `future/rds.tf` was subsequently updated during Phase 10 to consume Secrets Manager-derived local values.

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 30
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  monitoring_interval = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Database"
  }
}
```

In the current staged repository configuration, the credential portion of this resource has evolved to:

```hcl
db_name  = var.db_name
username = local.rds_admin_username
password = local.rds_admin_password
```

The local values are populated from the staged AWS Secrets Manager integration documented in Phase 10. This later change does not alter the fact that the original Phase 08 RDS deployment was performed and validated using locally supplied Terraform credential variables.

### Configuration Summary

| Setting             | Configuration              | Purpose                                  |
| ------------------- | -------------------------- | ---------------------------------------- |
| Database Engine     | PostgreSQL 16              | Managed PostgreSQL database              |
| Instance Class      | `db.t3.micro`              | Small project/training instance          |
| Storage             | 20 GB GP2                  | Minimal training storage                 |
| Storage Encryption  | Enabled                    | Protect data at rest                     |
| Public Access       | Disabled                   | Keep database private                    |
| Multi-AZ            | Disabled                   | Reduce project cost                      |
| Backup Retention    | 1 day                      | Demonstrate automated backups            |
| Security Group      | Existing database SG       | Restrict PostgreSQL network access       |
| DB Subnet Group     | Private A + Private B      | Keep database within private network     |
| Parameter Group     | PostgreSQL 16 custom group | Enable connection logging                |
| Enhanced Monitoring | Disabled                   | Avoid unnecessary configuration/cost     |
| Deletion Protection | Disabled                   | Allow project teardown                   |
| Final Snapshot      | Skipped                    | Simplify temporary project destruction   |

Several settings intentionally favor a temporary project environment rather than a production deployment.

In particular:

```hcl
multi_az        = false
deletion_protection = false
skip_final_snapshot = true
```

were selected so the training resource could be deployed, validated, and later destroyed without maintaining unnecessary AWS resources.

---

### 4.7 Add Terraform Outputs

RDS-specific outputs are retained with the staged database implementation in:

`future/outputs_rds.tf`

```hcl
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
```

These outputs provide connection metadata that can be consumed by future application, administration, or monitoring components.

The outputs expose connection metadata but do not expose the database password.

---

## 5. Deployment

The commands in this section document the original Phase 08 deployment and validation workflow. They do not indicate that an RDS instance is currently deployed. Following successful validation, the temporary RDS resources were destroyed and their Terraform configuration was retained under `future/`.

Before deployment, the Terraform configuration was formatted and validated:

```powershell
terraform fmt
terraform validate
```

A Terraform execution plan was then generated:

```powershell
terraform plan
```

The plan was reviewed to confirm creation of the expected resources:

```text
aws_db_subnet_group.postgres
aws_db_parameter_group.postgres
aws_db_instance.postgres
```

The configuration was then deployed:

```powershell
terraform apply
```

Terraform provisioned the RDS subnet group, PostgreSQL parameter group, and RDS PostgreSQL instance.

RDS provisioning required several minutes because AWS had to create and initialize the managed database instance.

After successful deployment, Terraform returned the configured RDS outputs, including the endpoint, hostname, port, and database name.

---

## 6. Validation

Validation was performed using both Terraform and the AWS Management Console.

### Terraform Validation

The following commands were used:

```powershell
terraform validate
terraform plan
terraform apply
terraform output
```

Terraform confirmed that the configuration was syntactically valid and that the RDS resources were successfully managed through Terraform state.

### AWS Console Validation

The RDS deployment was also verified through the AWS Management Console.

The following configuration was confirmed:

1. The PostgreSQL RDS instance reached the **Available** state.
2. The database engine was PostgreSQL.
3. Public accessibility was set to **No**.
4. The database was associated with the expected VPC.
5. The RDS subnet group contained the two private subnets.
6. The existing database security group was attached.
7. Storage encryption was enabled.
8. Automated backup retention was configured.
9. The custom PostgreSQL parameter group was attached.
10. The RDS endpoint and port matched the Terraform outputs.

This console validation confirmed that the deployed AWS configuration matched the intended Terraform architecture.

---

## 7. Results

Phase 08 successfully deployed and validated a managed PostgreSQL database tier within the AWS networking project. After validation, the RDS resources were destroyed to prevent continued AWS charges, while the validated Terraform configuration was retained under `future/` for future integration.

The deployment demonstrated the integration of several previously created infrastructure components:

```text
VPC
 │
 ├── Private Subnet A ──┐
 │                      │
 ├── Private Subnet B ──┼── RDS DB Subnet Group
 │                      │
 │                      ▼
 │                RDS PostgreSQL
 │                      ▲
 │                      │
 └── Database Security Group
```

The validated RDS deployment demonstrated an instance that:

* Resided within the private network tier.
* Was not publicly accessible.
* Used the existing database security group.
* Used encrypted storage.
* Used automated backups.
* Used a custom PostgreSQL parameter group.
* Exposed connection metadata through Terraform outputs.
* Was provisioned, validated, and removed through Terraform during the Phase 08 deployment lifecycle.

After validation, the temporary RDS resources were destroyed to prevent continued AWS charges:

```powershell
terraform destroy
```

This teardown was appropriate for the training environment and does not represent the lifecycle strategy that would normally be used for a production database.

---

## 8. Troubleshooting and Operational Notes

### RDS Provisioning Time

Unlike many networking resources, an RDS instance is not created immediately.

Terraform may remain in a state similar to:

```text
Still creating...
```

for several minutes while AWS provisions and initializes the database.

This is normal behavior and should not be interpreted as a Terraform failure unless an actual error is returned.

### DB Subnet Requirements

The DB subnet group must contain appropriate subnets across the required Availability Zones.

The private subnets created during the Multi-AZ networking phase satisfied this requirement.

### Security Group Connectivity

Setting:

```hcl
publicly_accessible = false
```

does not by itself determine which internal resources can connect to PostgreSQL.

Connectivity is also governed by the database security group created during the earlier security-group phase.

The intended access path is:

```text
Authorized Application Security Group
                 │
                 │ TCP/5432
                 ▼
        Database Security Group
                 │
                 ▼
           RDS PostgreSQL
```

### Terraform State and Passwords

Although:

```hcl
sensitive = true
```

prevents the password from being displayed normally by Terraform, the database credential can still be present within Terraform state.

Therefore, production Terraform state must also be protected through appropriate access controls and encryption.

---

## 9. Security Considerations

The RDS implementation follows several important database security principles.

### Private Database Placement

The database was deployed using private subnets and configured with:

```hcl
publicly_accessible = false
```

This prevents direct public Internet exposure of the RDS instance.

### Security Group Isolation

The existing database security group controls network access to PostgreSQL.

Database access should originate only from specifically authorized security groups rather than broad CIDR ranges. In the validated project design, PostgreSQL access is permitted from the application security group to the database security group.

The intended model is:

```text
Internet
   │
   ▼
Public Tier
   │
   ▼
Authorized Application
   │
   │ TCP/5432
   ▼
Database Security Group
   │
   ▼
Private Database Tier
   │
   ▼
RDS PostgreSQL
```

### Encryption at Rest

Storage encryption was enabled:

```hcl
storage_encrypted = true
```

This ensures that the underlying RDS database storage is encrypted at rest.

### Credential Protection

During the original training deployment, the database password was supplied through a sensitive Terraform variable using a local, ignored `terraform.tfvars` file. The credential was not intentionally committed to GitHub.

The project was subsequently extended with staged AWS Secrets Manager configuration under `future/`, together with supporting data and IAM configuration. These resources represent the intended stronger credential-management model but are not currently deployed.

Regardless of the mechanism used to supply credentials, sensitive values must not be committed to source control, and Terraform state containing sensitive data must be appropriately protected.

### Terraform State Protection

Sensitive Terraform variables can still be stored within Terraform state.

Therefore, remote state storage should be encrypted and protected through restrictive IAM permissions.

### Backup Protection

Automated backup retention was enabled:

```hcl
backup_retention_period = 1
```

The one-day retention period was selected for the project. Production systems would typically require a retention policy based on recovery objectives and organizational requirements.

### Project-Specific Controls

The following settings are appropriate for temporary training infrastructure but would require reconsideration for production:

```hcl
multi_az            = false
deletion_protection = false
skip_final_snapshot = true
```

A production implementation would normally evaluate:

* Multi-AZ deployment for database availability.
* Deletion protection.
* Longer backup retention.
* Final snapshots before deletion.
* Secrets Manager integration.
* Customer-managed KMS encryption where required.
* Enhanced monitoring.
* Performance Insights or equivalent database observability.
* CloudWatch log exports.
* More restrictive IAM permissions.

---

## 10. Lessons Learned

This phase demonstrated that deploying a database into AWS involves more than simply creating an RDS instance.

The database depends on several infrastructure layers created during previous phases:

```text
VPC
 ↓
Private Subnets
 ↓
Routing / NACL Controls
 ↓
Security Groups
 ↓
RDS Subnet Group
 ↓
RDS PostgreSQL
```

Key lessons from this phase include:

1. **RDS subnet groups define database network placement.**
   Providing private subnets from multiple Availability Zones gives RDS appropriate placement options without making the database publicly accessible.

2. **A Multi-AZ subnet group does not mean the database itself is Multi-AZ.**
   High availability requires the RDS Multi-AZ configuration to be explicitly enabled.

3. **Private accessibility and security groups work together.**
   `publicly_accessible = false` prevents public exposure, while security groups determine which authorized resources can establish database connections.

4. **Encryption should be enabled when the database is created.**
   Storage encryption provides an important baseline control for protecting data at rest.

5. **Sensitive Terraform variables are not equivalent to secret storage.**
   Terraform can suppress sensitive values from normal output, but credentials can still exist in Terraform state.

6. **Database credentials should not be stored in source control.**
   `.gitignore` provides a basic safeguard for the training project, while production environments should use dedicated secrets-management mechanisms.

7. **Backup and deletion settings should reflect the environment.**
   Short retention periods, disabled deletion protection, and skipped final snapshots simplify project teardown but are generally inappropriate defaults for production databases.

8. **RDS demonstrates dependency between infrastructure layers.**
   The database deployment validates the purpose of the VPC, private subnet, Multi-AZ network, NACL, and security-group work completed during earlier phases.

9. **Cost management is part of infrastructure lifecycle engineering.**
   Because RDS incurs ongoing charges while provisioned, the Phase 08 instance was destroyed after successful validation. Retaining the validated Terraform configuration under `future/` preserves the engineering work without requiring the database to remain running.

---

## 11. Phase Completion

Phase 08 successfully deployed and validated an Amazon RDS for PostgreSQL database within the private network tier.

The phase deployed and validated the following architecture, which is no longer running and is now represented by staged Terraform configuration under `future/`:

```text
                    AWS VPC
                       │
        ┌──────────────┴──────────────┐
        │                             │
 Public Subnet A                Public Subnet B
        │                             │
        └──────────────┬──────────────┘
                       │
              Authorized Access
                       │
                       ▼
             Database Security Group
                 PostgreSQL 5432
                       │
        ┌──────────────┴──────────────┐
        │                             │
Private Subnet A               Private Subnet B
        │                             │
        └──────────────┬──────────────┘
                       │
                DB Subnet Group
                       │
                       ▼
              Amazon RDS PostgreSQL
              ├── Private access only
              ├── Encrypted storage
              ├── Automated backups
              ├── Custom parameter group
              └── Terraform managed
```

The deployment verified integration among the project's private subnets, DB subnet group, database security group, PostgreSQL parameter group, encrypted RDS storage, automated backups, and Terraform-managed database lifecycle.

Following validation, the RDS resources were destroyed to avoid ongoing AWS charges. The validated database Terraform configuration is retained under `future/` and is therefore staged for future integration rather than part of the currently deployed networking baseline.

Subsequent phases build on the validated database design by documenting staged monitoring, alerting, secrets management, and security-hardening capabilities.
