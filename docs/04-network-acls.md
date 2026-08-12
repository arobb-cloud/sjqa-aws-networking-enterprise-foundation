# Phase 04 — Network Access Control Lists (NACLs)

## Purpose

The purpose of this phase is to add **subnet-level network traffic controls** to the AWS VPC by implementing custom Network Access Control Lists (NACLs).
Phase 03 introduced Security Groups to control traffic at the individual AWS resource or network-interface level. Phase 04 adds a second layer of network security by controlling which traffic can enter or leave the **public and private subnets**.

The NACL configuration will support:

* Public subnet web traffic
* Private subnet traffic
* PostgreSQL database traffic
* SSH management traffic
* Application traffic
* Ephemeral return traffic

Network ACLs operate at the subnet boundary and provide a coarse-grained network security layer in addition to Security Groups.

A key architectural distinction is:

* **Security Groups are stateful.**
* **Network ACLs are stateless.**

Because NACLs are stateless, return traffic is not automatically permitted. Appropriate inbound and outbound rules must therefore be configured for both directions.

---

## Objectives

The objectives of this phase are to:

* Create a custom NACL for the public subnet.
* Create a custom NACL for the private subnet.
* Associate each NACL with its appropriate subnet.
* Allow HTTP and HTTPS traffic for public-facing resources.
* Support SSH management traffic.
* Permit PostgreSQL traffic inside the VPC.
* Configure ephemeral ports required for TCP response traffic.
* Configure explicit inbound and outbound NACL rules.
* Export the NACL IDs through Terraform outputs.
* Validate and apply the Terraform configuration.
* Understand the difference between stateful Security Groups and stateless Network ACLs.

---

## Prerequisites

Before beginning this phase, the following components should already exist:

* AWS VPC
* Public subnet
* Private subnet
* Internet Gateway
* Public route table
* Private route table
* Security Groups from Phase 03
* Terraform AWS provider configuration
* Terraform remote or local state
* Working AWS CLI credentials
* Terraform configuration that successfully passes `terraform validate`

The NACL resources created in this phase reference existing resources including:

```text
aws_vpc.main
aws_subnet.public_a
aws_subnet.private_a
```

---

# Network ACL Design

The network controls introduced in this phase operate at the subnet level.

The conceptual architecture is:

```text
                         Internet
                            │
                            ▼
                     Internet Gateway
                            │
                            ▼
                ┌─────────────────────┐
                │    Public NACL      │
                └─────────────────────┘
                            │
                     Public Subnet
                            │
               ┌───────────────────────┐
               │ Bastion / App Server  │
               └───────────────────────┘
                            │
                     Security Groups
                            │
                ┌─────────────────────┐
                │    Private NACL     │
                └─────────────────────┘
                            │
                     Private Subnet
                            │
               ┌───────────────────────┐
               │ PostgreSQL / RDS      │
               └───────────────────────┘
```

This creates multiple layers of network control.

```text
Subnet Boundary
      │
      ▼
Network ACL
      │
      ▼
Security Group
      │
      ▼
AWS Resource
```

The NACL determines whether traffic is permitted through the subnet boundary.

The Security Group determines whether the traffic is permitted to reach the individual resource.

---

# Traffic Model

## Public Subnet

The public NACL permits:

| Direction | Protocol |       Port | Source / Destination | Purpose                    |
| --------- | -------- | ---------: | -------------------- | -------------------------- |
| Inbound   | TCP      |         80 | `0.0.0.0/0`          | HTTP                       |
| Inbound   | TCP      |        443 | `0.0.0.0/0`          | HTTPS                      |
| Inbound   | TCP      |         22 | `0.0.0.0/0`          | SSH subnet-level allowance |
| Inbound   | TCP      | 1024–65535 | `0.0.0.0/0`          | Ephemeral return traffic   |
| Outbound  | TCP      |         80 | `0.0.0.0/0`          | HTTP                       |
| Outbound  | TCP      |        443 | `0.0.0.0/0`          | HTTPS                      |
| Outbound  | TCP      | 1024–65535 | `0.0.0.0/0`          | Ephemeral TCP traffic      |

The Security Groups from Phase 03 provide the more granular resource-level controls.

---

## Private Subnet

The private NACL permits:

| Direction | Protocol |       Port | Source / Destination | Purpose                  |
| --------- | -------- | ---------: | -------------------- | ------------------------ |
| Inbound   | TCP      |       5432 | VPC CIDR             | PostgreSQL               |
| Inbound   | TCP      |         22 | VPC CIDR             | SSH from within VPC      |
| Inbound   | TCP      | 1024–65535 | VPC CIDR             | Ephemeral return traffic |
| Outbound  | TCP      |       5432 | VPC CIDR             | PostgreSQL communication |
| Outbound  | TCP      |         80 | `0.0.0.0/0`          | HTTP                     |
| Outbound  | TCP      |        443 | `0.0.0.0/0`          | HTTPS                    |
| Outbound  | TCP      | 1024–65535 | VPC CIDR             | Ephemeral return traffic |

Allowing HTTP or HTTPS in the NACL does not itself provide Internet connectivity to the private subnet. Routing infrastructure such as a NAT Gateway would also be required for private resources to initiate Internet-bound connections.

---

# Implementation

## 1. Create the Network ACL Terraform File

From the Terraform project directory, create:

```powershell
New-Item network_acls.tf
```

The file will contain both NACL resources and their associated rules.

---

## 2. Create the Public Network ACL

Add the following resource:

```hcl
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_a.id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-nacl"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Public"
  }
}
```

This resource creates a custom Network ACL and associates it with the public subnet.

The association is established through:

```hcl
subnet_ids = [aws_subnet.public_a.id]
```

---

## 3. Create the Private Network ACL

Add:

```hcl
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_a.id]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-nacl"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Private"
  }
}
```

This resource creates the private subnet NACL and associates it with:

```text
aws_subnet.private_a
```

---

# Public Subnet NACL Rules

## 4. Allow Inbound HTTP

```hcl
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
```

This allows HTTP requests to cross the public subnet boundary.

---

## 5. Allow Inbound HTTPS

```hcl
resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
```

This allows HTTPS traffic into the public subnet.

---

## 6. Allow Inbound SSH

```hcl
resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}
```

This permits SSH at the subnet boundary.

The NACL provides only one layer of access control. SSH access should still be restricted through the Bastion or management Security Group rather than relying solely on the NACL.

---

## 7. Allow Inbound Ephemeral Traffic

```hcl
resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
```

Ephemeral ports are required because TCP connections normally use dynamically assigned client-side ports.

Because NACLs are stateless, response traffic must have a corresponding rule allowing it through the opposite direction.

---

## 8. Configure Public Outbound Rules

Allow HTTP:

```hcl
resource "aws_network_acl_rule" "public_outbound_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
```

Allow HTTPS:

```hcl
resource "aws_network_acl_rule" "public_outbound_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
```

Allow ephemeral traffic:

```hcl
resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
```

---

# Private Subnet NACL Rules

## 9. Allow PostgreSQL Traffic from the VPC

```hcl
resource "aws_network_acl_rule" "private_inbound_postgres_from_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 5432
  to_port        = 5432
}
```

This allows PostgreSQL traffic originating from inside the VPC to cross the private subnet boundary.

The database Security Group from Phase 03 provides the more precise control over which application or management resources can actually establish the database connection.

---

## 10. Allow SSH from Within the VPC

```hcl
resource "aws_network_acl_rule" "private_inbound_ssh_from_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 22
  to_port        = 22
}
```

This permits SSH traffic originating within the VPC.

This could support administrative access through a bastion host or other approved management system.

---

## 11. Allow Private Inbound Ephemeral Traffic

```hcl
resource "aws_network_acl_rule" "private_inbound_ephemeral_from_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 1024
  to_port        = 65535
}
```

This allows TCP response traffic originating from resources within the VPC.

---

## 12. Configure Private Outbound Rules

Allow PostgreSQL:

```hcl
resource "aws_network_acl_rule" "private_outbound_postgres_to_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 5432
  to_port        = 5432
}
```

Allow HTTP:

```hcl
resource "aws_network_acl_rule" "private_outbound_http" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
```

Allow HTTPS:

```hcl
resource "aws_network_acl_rule" "private_outbound_https" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
```

Allow ephemeral traffic:

```hcl
resource "aws_network_acl_rule" "private_outbound_ephemeral_to_vpc" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 1024
  to_port        = 65535
}
```

---

# Update Terraform Outputs

## 13. Update `outputs.tf`

Add outputs for both custom Network ACLs:

```hcl
output "public_network_acl_id" {
  value = aws_network_acl.public.id
}

output "private_network_acl_id" {
  value = aws_network_acl.private.id
}
```

These outputs make it easier to verify the NACL resources after deployment and reference their identifiers during troubleshooting.

---

# Terraform Validation

## 14. Format the Terraform Configuration

Run:

```powershell
terraform fmt
```

This normalizes Terraform formatting.

---

## 15. Validate the Configuration

Run:

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

---

## 16. Review the Terraform Plan

Run:

```powershell
terraform plan -out=tfplan
```

Review the plan before applying.

The plan should show creation of:

* Public Network ACL
* Private Network ACL
* Public NACL rules
* Private NACL rules
* Subnet-to-NACL associations

No unexpected infrastructure should be destroyed or replaced.

---

# Deployment

## 17. Apply the Terraform Configuration

After confirming the plan:

```powershell
terraform apply tfplan
```

Alternatively, if a saved plan is not being used:

```powershell
terraform apply
```

Confirm the deployment when prompted.

---

# Post-Deployment Validation

## 18. Verify Terraform State

Run:

```powershell
terraform state list
```

Verify that resources similar to the following appear:

```text
aws_network_acl.public
aws_network_acl.private

aws_network_acl_rule.public_inbound_http
aws_network_acl_rule.public_inbound_https
aws_network_acl_rule.public_inbound_ssh
aws_network_acl_rule.public_inbound_ephemeral

aws_network_acl_rule.public_outbound_http
aws_network_acl_rule.public_outbound_https
aws_network_acl_rule.public_outbound_ephemeral

aws_network_acl_rule.private_inbound_postgres_from_vpc
aws_network_acl_rule.private_inbound_ssh_from_vpc
aws_network_acl_rule.private_inbound_ephemeral_from_vpc

aws_network_acl_rule.private_outbound_postgres_to_vpc
aws_network_acl_rule.private_outbound_http
aws_network_acl_rule.private_outbound_https
aws_network_acl_rule.private_outbound_ephemeral_to_vpc
```

---

## 19. Verify Terraform Outputs

Run:

```powershell
terraform output
```

Expected outputs should now include:

```text
public_network_acl_id
private_network_acl_id
```

For example:

```text
public_network_acl_id  = "acl-xxxxxxxxxxxxxxxxx"
private_network_acl_id = "acl-xxxxxxxxxxxxxxxxx"
```

The exact IDs are assigned dynamically by AWS.

---

# Expected Result

At the completion of Phase 04, the VPC should contain two custom Network ACLs:

```text
VPC
│
├── Public Subnet
│     │
│     └── Public NACL
│           ├── HTTP
│           ├── HTTPS
│           ├── SSH
│           └── Ephemeral traffic
│
└── Private Subnet
      │
      └── Private NACL
            ├── PostgreSQL
            ├── SSH from VPC
            ├── HTTP/HTTPS outbound
            └── Ephemeral traffic
```

The resulting network security model becomes:

```text
Internet / VPC Traffic
        │
        ▼
     Routing
        │
        ▼
  Network ACL
  (subnet level)
        │
        ▼
 Security Group
(resource level)
        │
        ▼
 EC2 / PostgreSQL / RDS
```

---

# Key Concept — Stateful vs. Stateless Controls

One of the primary learning objectives of this phase is understanding the difference between Security Groups and Network ACLs.

## Security Groups

Security Groups are **stateful**.

For example, if an inbound Security Group rule permits:

```text
Client
   │
   │ TCP 5432
   ▼
PostgreSQL
```

the response traffic is automatically permitted as part of the established connection.

A separate Security Group rule for the return connection is not required.

---

## Network ACLs

Network ACLs are **stateless**.

For example:

```text
Client
   │
   │ Request
   ▼
Private Subnet
```

and:

```text
Client
   ▲
   │ Response
   │
Private Subnet
```

are evaluated independently.

The NACL must therefore contain rules that allow both paths.

This is the reason ephemeral port rules appear throughout the configuration.

---

# NACL Rule Evaluation

Network ACL rules are evaluated according to their rule numbers, beginning with the lowest numbered rule.

For example:

```text
100
110
120
130
```

AWS evaluates the lowest matching rule first.

The numbering scheme intentionally leaves gaps between rules so additional rules can be inserted later.

For example:

```text
100
105    <- future rule
110
120
```

This avoids having to renumber the entire ACL.

Traffic that does not match an explicit allow rule eventually reaches the NACL's default `*` rule and is denied.

---

# Security Architecture

Phase 03 and Phase 04 now work together as complementary controls.

```text
                 Network Security Layers

                        Traffic
                           │
                           ▼
                  ┌─────────────────┐
                  │      NACL       │
                  │ Subnet Boundary │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ Security Group  │
                  │ Resource Access │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ AWS Resource    │
                  │ EC2 / RDS / DB  │
                  └─────────────────┘
```

The responsibilities are different:

| Control        | Scope        | State     |
| -------------- | ------------ | --------- |
| Network ACL    | Subnet       | Stateless |
| Security Group | ENI/resource | Stateful  |

The NACL serves as a broad subnet boundary.

The Security Group provides fine-grained access control to individual workloads.

---

# Security Considerations

### Public SSH

The public NACL currently permits TCP port 22 from:

```text
0.0.0.0/0
```

This means the **subnet boundary** does not reject SSH based on source address.

The Security Group should therefore provide the more restrictive SSH rule, such as allowing access only from an approved administrative IP address.

For a more restrictive production architecture, the NACL itself could also be narrowed to a trusted CIDR.

### PostgreSQL

The private NACL permits PostgreSQL traffic from the VPC CIDR:

```hcl
cidr_block = aws_vpc.main.cidr_block
```

This should not be interpreted as allowing every VPC resource to connect to PostgreSQL.

The database Security Group remains responsible for determining which workloads may actually establish a PostgreSQL connection.

For example:

```text
Application SG
      │
      │ TCP 5432
      ▼
Database SG
```

The NACL acts as the subnet-level boundary while the Security Group enforces the workload-level relationship.

### Private Internet Access

The private NACL contains outbound HTTP and HTTPS allowances to:

```text
0.0.0.0/0
```

These rules only permit such packets through the NACL.

They do not create a route to the Internet.

Private subnet Internet access requires additional routing infrastructure such as:

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
Internet Gateway
      │
      ▼
Internet
```

That architecture is addressed separately in the NAT Gateway phase.

---

# Phase Completion Criteria

Phase 04 is complete when:

* A public custom Network ACL exists.
* A private custom Network ACL exists.
* The public NACL is associated with the public subnet.
* The private NACL is associated with the private subnet.
* HTTP traffic is represented in the public NACL.
* HTTPS traffic is represented in the public NACL.
* SSH traffic is represented in the applicable NACL rules.
* PostgreSQL TCP/5432 is represented in the private NACL.
* Ephemeral return ports are configured.
* Both inbound and outbound paths have been considered.
* Terraform formatting succeeds.
* Terraform validation succeeds.
* The Terraform plan contains the expected NACL resources.
* Terraform apply completes successfully.
* `terraform state list` shows the NACL resources and rules.
* `terraform output` returns the public and private NACL IDs.
* The difference between stateful Security Groups and stateless Network ACLs is understood.

---

# Phase 04 Result

Phase 04 adds a second network security layer to the custom AWS VPC.

Phase 03 established:

```text
Security Groups
       │
       └── Resource-level access controls
```

Phase 04 adds:

```text
Network ACLs
       │
       └── Subnet-level traffic controls
```

Together:

```text
Network ACL
    │
    ▼
Security Group
    │
    ▼
AWS Resource
```

This establishes a layered network security model that can be expanded as the architecture later introduces Multi-AZ networking, NAT Gateway routing, bastion management, RDS PostgreSQL, and additional enterprise security controls.
