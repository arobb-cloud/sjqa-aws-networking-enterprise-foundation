# Phase 08 – Amazon RDS PostgreSQL Deployment

## 1. Purpose

The purpose of this phase was to deploy an Amazon RDS for PostgreSQL database into the private database tier of the VPC.

This phase builds on the networking and security controls implemented during the previous phases by placing the database within the existing private subnets and associating it with the previously created database security group.

The deployment was designed to demonstrate a basic production-oriented database architecture while keeping the lab configuration small enough for a training and portfolio environment.

The resulting traffic pattern is:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Subnets
   │
   │  Management/Application Tier
   │
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

---

## 3. Architecture

Phase 08 extends the existing Multi-AZ network architecture by introducing a managed PostgreSQL database tier.

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
                 Application / Bastion
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

The following variables were added to `variables.tf`:

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

For this lab, `terraform.tfvars` remained local to the workstation.

> **Security Note:** A production implementation should retrieve database credentials from a dedicated secrets-management mechanism, such as AWS Secrets Manager, or securely inject the value through a CI/CD secrets system. The local `terraform.tfvars` approach was used only for the training deployment.

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

A new Terraform file was created:

```text
terraform/rds.tf
```

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

The PostgreSQL RDS instance was defined as:

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 20
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

### Configuration Summary

| Setting             | Configuration              | Purpose                                  |
| ------------------- | -------------------------- | ---------------------------------------- |
| Database Engine     | PostgreSQL 16              | Managed PostgreSQL database              |
| Instance Class      | `db.t3.micro`              | Small lab/training instance              |
| Storage             | 20 GB GP2                  | Minimal training storage                 |
| Storage Encryption  | Enabled                    | Protect data at rest                     |
| Public Access       | Disabled                   | Keep database private                    |
| Multi-AZ            | Disabled                   | Reduce lab cost                          |
| Backup Retention    | 1 day                      | Demonstrate automated backups            |
| Security Group      | Existing database SG       | Restrict PostgreSQL network access       |
| DB Subnet Group     | Private A + Private B      | Keep database within private network     |
| Parameter Group     | PostgreSQL 16 custom group | Enable connection logging                |
| Enhanced Monitoring | Disabled                   | Avoid unnecessary lab configuration/cost |
| Deletion Protection | Disabled                   | Allow lab teardown                       |
| Final Snapshot      | Skipped                    | Simplify temporary lab destruction       |

Several settings intentionally favor a temporary lab environment rather than a production deployment.

In particular:

```hcl
multi_az        = false
deletion_protection = false
skip_final_snapshot = true
```

were selected so the training resource could be deployed, validated, and later destroyed without maintaining unnecessary AWS resources.

---

### 4.7 Add Terraform Outputs

The following outputs were added to `outputs.tf`:

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

These outputs provide the connection information required by future application, bastion, administration, or monitoring components.

The outputs expose connection metadata but do not expose the database password.

---

## 5. Deployment

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

Phase 08 successfully introduced a managed database tier into the AWS networking project.

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

The resulting RDS instance:

* Resided within the private network tier.
* Was not publicly accessible.
* Used the existing database security group.
* Used encrypted storage.
* Used automated backups.
* Used a custom PostgreSQL parameter group.
* Exposed connection metadata through Terraform outputs.
* Was completely managed through Terraform.

After validation, the temporary RDS resources could be destroyed to prevent continued AWS charges:

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
Authorized Application/Bastion Security Group
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

Database access should originate only from specifically authorized application or management security groups rather than broad CIDR ranges whenever possible.

The intended model is:

```text
Internet
   │
   ▼
Public Tier
   │
   ▼
Authorized Application/Bastion
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

The database password was defined as a sensitive Terraform variable and stored only in a local ignored `terraform.tfvars` file for the training deployment.

The credential was not intentionally committed to GitHub.

A production architecture should replace this approach with AWS Secrets Manager or another approved secrets-management workflow.

### Terraform State Protection

Sensitive Terraform variables can still be stored within Terraform state.

Therefore, remote state storage should be encrypted and protected through restrictive IAM permissions.

### Backup Protection

Automated backup retention was enabled:

```hcl
backup_retention_period = 1
```

The one-day retention period was selected for the lab. Production systems would typically require a retention policy based on recovery objectives and organizational requirements.

### Lab-Specific Controls

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
   Short retention periods, disabled deletion protection, and skipped final snapshots simplify lab teardown but are generally inappropriate defaults for production databases.

8. **RDS demonstrates dependency between infrastructure layers.**
   The database deployment validates the purpose of the VPC, private subnet, Multi-AZ network, NACL, and security-group work completed during earlier phases.

9. **Cost management is part of infrastructure engineering.**
   Because RDS is a continuously running managed service, temporary training resources should be destroyed after validation when they are no longer required.

---

## 11. Phase Completion

Phase 08 successfully deployed and validated an Amazon RDS for PostgreSQL database within the private network tier.

The phase established the following architecture:

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

This phase completes the initial private database deployment and establishes the database resource that can be extended in subsequent phases with monitoring, alerting, secrets management, and additional enterprise hardening controls.
