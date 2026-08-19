# Phase 03 — Security Groups

## Purpose

The purpose of this phase is to implement reusable AWS Security Groups that provide network-level access control between the management, application, and database tiers of the VPC.

The security model is designed to support current networking controls and future workloads, including:

* PostgreSQL database workloads.
* Application servers.
* Bastion or management hosts.
* Future Amazon RDS deployments.
* Future Amazon EC2 application workloads.

The design follows a tiered security model in which database access is restricted to authorized application-tier resources rather than being exposed directly to the Internet.

---

## Objectives

The objectives of this phase are to:

* Create separate Security Groups for the database, application, and management tiers.
* Allow PostgreSQL traffic from the application tier to the database tier over TCP port `5432`.
* Establish controlled administrative access between management and application tiers.
* Prevent direct Internet access to the database tier.
* Configure outbound connectivity for each Security Group.
* Manage Security Group rules as standalone Terraform resources.
* Expose Security Group IDs as Terraform outputs for use by later infrastructure phases.

---

## Architecture / Design

The Security Groups provide logical access controls between infrastructure tiers.

```text
Management Tier
      │
      │ Administrative Access
      ▼
Application Tier
      │
      │ PostgreSQL TCP/5432
      ▼
Database Tier
```

The Security Groups establish reusable network boundaries even when corresponding compute or database workloads are not currently deployed.

The primary security principle is:

> Only authorized application-tier resources should be able to initiate PostgreSQL connections to the database tier. Management access should be permitted only where operationally necessary.

### Security Group Relationships

| Source         | Destination    | Protocol | Port | Purpose                          |
| -------------- | -------------- | -------- | ---: | -------------------------------- |
| Application SG | Database SG    | TCP      | 5432 | PostgreSQL database connectivity |
| Management SG  | Application SG | TCP      |   22 | Administrative SSH access        |
| Database SG    | Outbound       | All      |  All | Outbound traffic                 |
| Application SG | Outbound       | All      |  All | Outbound traffic                 |
| Management SG  | Outbound       | All      |  All | Outbound traffic                 |

Security Group references are used instead of fixed source CIDR ranges for inter-tier communication where appropriate. This allows resources associated with an approved source Security Group to communicate with the destination tier without depending on individual instance IP addresses.

The optional bastion configuration introduced later uses an additional CIDR-based ingress rule on the Management Security Group so that administrative SSH access can be restricted to a configured source network.

---

## Implementation

### 1. Create the Security Groups Terraform File

Create a dedicated Terraform configuration file for Security Group resources:

```powershell
New-Item security_groups.tf
```

This separates Security Group configuration from VPC and subnet configuration and makes the network security policy easier to maintain.

---

### 2. Create the Database Security Group

Add the database Security Group to `security_groups.tf`:

```hcl
resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-database-sg"
  description = "Security Group for PostgreSQL databases"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Database"
  }
}
```

The database Security Group is intended for PostgreSQL workloads, including the Amazon RDS PostgreSQL configuration evaluated in a later phase.

Ingress and egress rules are managed separately rather than being defined inline.

---

### 3. Create the Application Security Group

```hcl
resource "aws_security_group" "application" {
  name        = "${var.project_name}-${var.environment}-application-sg"
  description = "Security Group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-application-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Application"
  }
}
```

This Security Group represents application-tier workloads that may require access to PostgreSQL.

The Security Group itself remains useful as part of the active network-security foundation even when an application workload is not currently deployed.

---

### 4. Create the Management Security Group

```hcl
resource "aws_security_group" "management" {
  name        = "${var.project_name}-${var.environment}-management-sg"
  description = "Security Group for Bastion or Management hosts"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-management-sg"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Management"
  }
}
```

The Management Security Group provides a logical security boundary for administrative systems such as the optional bastion host introduced in a later phase.

The Management Security Group is part of the active Terraform networking configuration even when the optional bastion EC2 instance is disabled.

---

### 5. Allow PostgreSQL Access from the Application Tier

Create a standalone ingress rule permitting application-tier resources to communicate with the database tier over PostgreSQL TCP port `5432`:

```hcl
resource "aws_vpc_security_group_ingress_rule" "postgres_from_application" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "Allow PostgreSQL from Application Security Group"
}
```

This rule references the Application Security Group as the source rather than allowing a broad CIDR range.

As a result, PostgreSQL access is restricted to resources associated with the Application Security Group.

The rule establishes the permitted network path whether or not a database instance is currently deployed.

---

### 6. Allow SSH from the Management Tier

Create an ingress rule allowing resources associated with the Management Security Group to connect to application-tier resources using SSH:

```hcl
resource "aws_vpc_security_group_ingress_rule" "ssh_from_management" {
  security_group_id            = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.management.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Allow SSH from Management Security Group"
}
```

This establishes the following logical administrative path:

```text
Management SG
      │
      │ TCP/22
      ▼
Application SG
```

This rule does not authorize arbitrary Internet addresses to connect directly to the Application Security Group.

A later bastion phase adds a separate ingress mechanism for the Management Security Group, using a configurable source CIDR and feature-controlled bastion deployment.

---

### 7. Configure Outbound Traffic

Configure outbound access for each Security Group.

#### Database Security Group

```hcl
resource "aws_vpc_security_group_egress_rule" "database_all_outbound" {
  security_group_id = aws_security_group.database.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}
```

#### Application Security Group

```hcl
resource "aws_vpc_security_group_egress_rule" "application_all_outbound" {
  security_group_id = aws_security_group.application.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}
```

#### Management Security Group

```hcl
resource "aws_vpc_security_group_egress_rule" "management_all_outbound" {
  security_group_id = aws_security_group.management.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound traffic"
}
```

The broad outbound rules simplify connectivity for the project environment. More restrictive egress policies could be introduced in a future hardening iteration if required.

---

### 8. Add Terraform Outputs

Add Security Group IDs to `outputs.tf`:

```hcl
output "database_security_group_id" {
  value = aws_security_group.database.id
}

output "application_security_group_id" {
  value = aws_security_group.application.id
}

output "management_security_group_id" {
  value = aws_security_group.management.id
}
```

These outputs make the Security Group IDs available for validation and use by later infrastructure components.

---

## Validation

Format the Terraform configuration:

```powershell
terraform fmt
```

Validate the Terraform syntax and resource configuration:

```powershell
terraform validate
```

Generate and review the execution plan:

```powershell
terraform plan -out=tfplan
```

If the plan is correct, apply the reviewed configuration:

```powershell
terraform apply tfplan
```

After deployment, verify that Terraform is tracking the Security Groups and associated rules:

```powershell
terraform state list
```

Verify the Terraform outputs:

```powershell
terraform output
```

Expected Security Group outputs include:

```text
application_security_group_id
database_security_group_id
management_security_group_id
```

---

## Results

This phase establishes three reusable Security Groups:

* **Database Security Group** — provides the network-security boundary for PostgreSQL workloads and staged Amazon RDS integration.
* **Application Security Group** — provides the network-security boundary for application-tier workloads.
* **Management Security Group** — provides the network-security boundary for administrative resources and the optional bastion design.

The resulting logical access model is:

```text
Management
    │
    │ SSH : 22
    ▼
Application
    │
    │ PostgreSQL : 5432
    ▼
Database
```

This diagram represents permitted Security Group relationships. It does not imply that application servers, a bastion host, or an RDS database are currently deployed.

The database tier does not receive a rule permitting direct inbound Internet access.

---

## Current Repository State

The Security Groups created in this phase remain part of the active Terraform configuration under `terraform/`.

The current repository distinguishes these persistent network-security controls from optional or staged workloads:

* The Database, Application, and Management Security Groups remain active Terraform resources.
* The bastion host configuration remains under `terraform/` but is disabled by default through `enable_bastion = false`.
* The bastion SSH ingress configuration is associated with the Management Security Group and is controlled using the configured management source CIDR.
* Amazon RDS PostgreSQL configuration is retained under `future/` and is not part of the current active deployment.
* Application-tier compute resources are not currently deployed.

This allows the network-security foundation to remain defined independently of cost-sensitive or future workloads.

---

## Key Concepts Learned

### Security Groups as Tier-Based Controls

Security Groups can represent infrastructure roles rather than individual servers.

Instead of creating security policies around specific instance IP addresses, this implementation establishes:

```text
Management Tier
Application Tier
Database Tier
```

This makes the design reusable when EC2 instances, RDS databases, or other workloads are introduced.

### Security Group Referencing

AWS Security Groups can reference other Security Groups as traffic sources.

For example:

```hcl
referenced_security_group_id = aws_security_group.application.id
```

means the database rule trusts resources associated with the Application Security Group rather than an arbitrary source IP range.

This provides a more maintainable security model as infrastructure changes.

### Standalone Security Group Rules

Terraform supports two common approaches for defining Security Group rules:

1. Inline rules within an `aws_security_group` resource.
2. Standalone resources such as `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`.

This project uses standalone rule resources.

Separating Security Groups from individual rules makes each rule explicit and independently manageable and avoids mixing inline and standalone rule-management approaches for the same Security Group.

### Stateful Firewall Behavior

AWS Security Groups are stateful.

When traffic is permitted for an established connection, response traffic is automatically allowed. Separate Security Group rules are therefore not required solely to permit return traffic for that connection.

---

## Phase Completion

Phase 03 established the network-security boundaries required by later phases of the project.

At completion of this phase, the Terraform configuration defined reusable security controls for:

* Management-tier resources.
* Application-tier resources.
* PostgreSQL database resources.
* Future EC2 workloads.
* Future Amazon RDS workloads.

The Security Groups remain part of the active networking foundation even though several workloads they are designed to protect are optional, staged, or currently undeployed.

The Terraform configuration was therefore prepared to support subsequent networking and workload phases while maintaining separation between infrastructure tiers.
