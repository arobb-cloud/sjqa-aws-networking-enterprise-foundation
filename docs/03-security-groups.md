# 03 — Security Groups

## Purpose

The purpose of this phase is to implement reusable AWS Security Groups that provide network-level access control between the management, application, and database tiers of the VPC.

The security model is designed to support current and future workloads, including:

* PostgreSQL database servers
* Application servers
* Bastion or management hosts
* Future Amazon RDS deployments
* Future Amazon EC2 deployments

The design follows a tiered security model in which access to the database tier is restricted to authorized application resources rather than being exposed directly to the internet.

---

## Objectives

The objectives of this phase are to:

* Create separate Security Groups for the database, application, and management tiers.
* Allow PostgreSQL traffic from the application tier to the database tier over TCP port 5432.
* Allow SSH access from the management tier to the application tier over TCP port 22.
* Prevent direct internet access to the database tier.
* Configure outbound connectivity for each Security Group.
* Manage Security Group rules as standalone Terraform resources.
* Expose Security Group IDs as Terraform outputs for use by later infrastructure phases.

---

## Architecture / Design

The Security Groups provide logical access controls between the infrastructure tiers.

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Subnet
   │
   ┌───────────────────────┐
   │ Bastion Host          │
   │ Application Server    │
   └───────────────────────┘
              │
              ▼
       Security Groups
              │
              ▼
Private Subnet
   │
   ┌───────────────────────┐
   │ PostgreSQL            │
   │ Amazon RDS            │
   └───────────────────────┘
```

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

Security Group references are used instead of fixed source CIDR ranges for inter-tier communication. This allows resources associated with the approved source Security Group to communicate with the destination tier without depending on individual instance IP addresses.

---

## Implementation

### 1. Create the Security Groups Terraform File

Create a dedicated Terraform configuration file for Security Group resources:

```powershell
New-Item security_groups.tf
```

This separates Security Group configuration from the VPC and subnet configuration and makes the network security policy easier to maintain.

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

The database Security Group is intended for PostgreSQL workloads, including the later Amazon RDS deployment.

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

The management Security Group provides a logical security boundary for administrative systems such as bastion hosts.

---

### 5. Allow PostgreSQL Access from the Application Tier

Create a standalone ingress rule permitting application-tier resources to communicate with the database tier over PostgreSQL's TCP port 5432:

```hcl
resource "aws_vpc_security_group_ingress_rule" "postgres_from_application" {
  security_group_id             = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.application.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"

  description = "Allow PostgreSQL from Application Security Group"
}
```

This rule references the Application Security Group as the source rather than allowing a broad CIDR range.

As a result, database access is restricted to resources associated with the Application Security Group.

---

### 6. Allow SSH from the Management Tier

Create an ingress rule allowing management resources to connect to application resources using SSH:

```hcl
resource "aws_vpc_security_group_ingress_rule" "ssh_from_management" {
  security_group_id             = aws_security_group.application.id
  referenced_security_group_id = aws_security_group.management.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Allow SSH from Management Security Group"
}
```

This establishes a controlled administrative path:

```text
Management SG
      │
      │ TCP/22
      ▼
Application SG
```

SSH is therefore not authorized by this rule from arbitrary internet addresses.

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

The broad outbound rules simplify connectivity during the initial implementation. More restrictive egress policies could be introduced later if required by the security model.

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

These outputs make the Security Group IDs available for validation and for use by later infrastructure components.

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

Generate and save the execution plan:

```powershell
terraform plan -out=tfplan
```

Review the plan before deploying the resources.

If the plan is correct, apply the configuration:

```powershell
terraform apply
```

After deployment, verify that Terraform is tracking the Security Groups and associated rules:

```powershell
terraform state list
```

Verify the Terraform outputs:

```powershell
terraform output
```

Expected outputs include:

```text
application_security_group_id
database_security_group_id
management_security_group_id
```

---

## Results

This phase establishes three reusable Security Groups:

* **Database Security Group** — protects PostgreSQL and future Amazon RDS resources.
* **Application Security Group** — provides the security boundary for application-tier resources.
* **Management Security Group** — provides the security boundary for bastion and administrative resources.

The resulting access model is:

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

The database tier does not receive a rule permitting direct inbound internet access.

---

## Key Concepts Learned

### Security Groups as Tier-Based Controls

Security Groups can represent infrastructure roles rather than individual servers.

Instead of creating security policies around specific IP addresses, this implementation establishes:

```text
Management Tier
Application Tier
Database Tier
```

This makes the design reusable when EC2 instances, RDS databases, or other workloads are introduced later.

### Security Group Referencing

AWS Security Groups can reference other Security Groups as traffic sources.

For example:

```hcl
referenced_security_group_id = aws_security_group.application.id
```

means the database rule trusts resources associated with the Application Security Group rather than an arbitrary IP range.

This provides a more maintainable security model as infrastructure changes.

### Standalone Security Group Rules

Terraform supports two common approaches for defining Security Group rules:

1. Inline rules within an `aws_security_group` resource.
2. Standalone resources such as `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`.

This project uses standalone rule resources.

Separating Security Groups from individual rules makes each rule explicit and independently manageable and helps avoid mixing inline and standalone rule-management approaches for the same Security Group.

### Stateful Firewall Behavior

AWS Security Groups are stateful.

When traffic is permitted into a resource, response traffic for that connection is automatically allowed. A separate inbound rule does not need to be created solely for the return traffic.

---

## Phase Completion

Phase 23 establishes the network security boundaries required by later phases of the project.

At completion, the VPC contains reusable security controls for:

* Management resources
* Application resources
* PostgreSQL database resources
* Future EC2 workloads
* Future Amazon RDS workloads

The environment is now prepared for subsequent networking and workload deployment phases while maintaining separation between infrastructure tiers.
