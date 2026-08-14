# Phase 05 — Multi-AZ Networking

## 1. Purpose

The purpose of this phase is to extend the existing AWS VPC network across a second Availability Zone.

The initial VPC architecture contained one public subnet and one private subnet in Availability Zone A. This phase adds a corresponding public and private subnet in Availability Zone B.

This creates a Multi-AZ network foundation that can support highly available AWS services and workloads in later phases.

---

## 2. Objectives

The objectives of this phase are to:

* Add a public subnet in Availability Zone B.
* Add a private subnet in Availability Zone B.
* Associate Public Subnet B with the existing public route table.
* Associate Private Subnet B with the existing private route table.
* Extend the public Network ACL to Public Subnet B.
* Extend the private Network ACL to Private Subnet B.
* Add Terraform outputs for the new subnet IDs.
* Validate and apply the Terraform configuration.
* Verify the resulting Multi-AZ network infrastructure.

---

## 3. Architecture

Before this phase, the VPC contained:

```text
VPC: 10.22.0.0/16
│
└── Availability Zone A
    ├── Public Subnet A
    │   └── 10.22.1.0/24
    │
    └── Private Subnet A
        └── 10.22.11.0/24
```

Phase 05 expands the network into a second Availability Zone:

```text
VPC: 10.22.0.0/16
│
├── Availability Zone A
│   ├── Public Subnet A
│   │   └── 10.22.1.0/24
│   │
│   └── Private Subnet A
│       └── 10.22.11.0/24
│
└── Availability Zone B
    ├── Public Subnet B
    │   └── 10.22.2.0/24
    │
    └── Private Subnet B
        └── 10.22.12.0/24
```

The resulting subnet design is:

| Subnet           | Availability Zone | CIDR Block      | Tier    |
| ---------------- | ----------------- | --------------- | ------- |
| Public Subnet A  | AZ-A              | `10.22.1.0/24`  | Public  |
| Public Subnet B  | AZ-B              | `10.22.2.0/24`  | Public  |
| Private Subnet A | AZ-A              | `10.22.11.0/24` | Private |
| Private Subnet B | AZ-B              | `10.22.12.0/24` | Private |

---

# 4. Implementation

## 4.1 Update the VPC Terraform Configuration

Open:

```text
terraform/vpc.tf
```

Add the Public Subnet B resource:

```hcl
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.22.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-b"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "public"
  }
}
```

Add the Private Subnet B resource:

```hcl
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.22.12.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-b"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "private"
  }
}
```

### What This Configuration Does

The `public_b` resource creates a second public subnet using the CIDR block:

```text
10.22.2.0/24
```

The subnet is placed in Availability Zone B using:

```hcl
availability_zone = "${var.aws_region}b"
```

Public IP assignment is enabled:

```hcl
map_public_ip_on_launch = true
```

This allows resources launched into the subnet to receive public IPv4 addresses when appropriate.

The `private_b` resource creates the corresponding private subnet:

```text
10.22.12.0/24
```

Public IP assignment is not enabled for this subnet because it belongs to the private network tier.

---

## 4.2 Add Route Table Associations

Add the following resources to `vpc.tf`:

```hcl
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
```

### Public Route Table Association

Public Subnet B is associated with the existing public route table:

```text
Public Subnet A ─┐
                 ├── Public Route Table ── Internet Gateway
Public Subnet B ─┘
```

This gives both public subnets the same public routing behavior.

### Private Route Table Association

Private Subnet B is associated with the existing private route table:

```text
Private Subnet A ─┐
                  ├── Private Route Table
Private Subnet B ─┘
```

Both private subnets therefore use the same private routing configuration.

---

## 4.3 Update Network ACL Subnet Associations

Open:

```text
terraform/network_acls.tf
```

Update the public Network ACL:

```hcl
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-nacl"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Public"
  }
}
```

The important change is the addition of:

```hcl
aws_subnet.public_b.id
```

The public Network ACL is now associated with both public subnets:

```text
Public NACL
│
├── Public Subnet A
└── Public Subnet B
```

Update the private Network ACL:

```hcl
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-nacl"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Private"
  }
}
```

The important change is:

```hcl
aws_subnet.private_b.id
```

The private Network ACL now applies to:

```text
Private NACL
│
├── Private Subnet A
└── Private Subnet B
```

The NACL rules created during Phase 04 do not need to be recreated. The existing controls are extended to the new subnets through these subnet associations.

---

## 4.4 Update Terraform Outputs

Open:

```text
terraform/outputs.tf
```

Add:

```hcl
output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}
```

These outputs expose the AWS subnet IDs for the new Availability Zone B subnets.

They can later be referenced when working with resources such as:

* EC2
* RDS
* NAT Gateways
* Load Balancers
* Auto Scaling
* RDS DB subnet groups

---

# 5. Deployment

## 5.1 Format the Terraform Configuration

Run:

```powershell
terraform fmt
```

This ensures that the Terraform files follow standard HCL formatting.

---

## 5.2 Validate the Configuration

Run:

```powershell
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

This verifies that Terraform can successfully parse the configuration and resolve the resource references.

---

## 5.3 Generate the Terraform Plan

Run:

```powershell
terraform plan -out=tfplan
```

Review the execution plan before applying the changes.

The plan should include creation of:

```text
aws_subnet.public_b
aws_subnet.private_b

aws_route_table_association.public_b
aws_route_table_association.private_b
```

Terraform should also update the Network ACL subnet associations to include the new AZ-B subnets.

The existing AZ-A infrastructure should remain intact.

---

## 5.4 Apply the Terraform Plan

Run:

```powershell
terraform apply tfplan
```

Terraform creates the new subnets and updates the required network associations.

A successful deployment should end with:

```text
Apply complete!
```

---

# 6. Post-Deployment Validation

## 6.1 Verify Terraform Outputs

Run:

```powershell
terraform output
```

Verify that the outputs include:

```text
public_subnet_b_id
private_subnet_b_id
```

The existing subnet and networking outputs should also remain available.

---

## 6.2 Verify the Multi-AZ Architecture

Confirm that the VPC now contains:

```text
Availability Zone A
├── Public Subnet A
└── Private Subnet A

Availability Zone B
├── Public Subnet B
└── Private Subnet B
```

Also verify that:

* Public Subnet A and Public Subnet B use the public route table.
* Private Subnet A and Private Subnet B use the private route table.
* Both public subnets are associated with the public Network ACL.
* Both private subnets are associated with the private Network ACL.

---

# 7. Results

Phase 05 expanded the VPC from a single-Availability-Zone design into a Multi-AZ network architecture.

The completed network now contains:

```text
AWS Region
│
└── VPC 10.22.0.0/16
    │
    ├── Availability Zone A
    │   ├── Public Subnet A  — 10.22.1.0/24
    │   └── Private Subnet A — 10.22.11.0/24
    │
    └── Availability Zone B
        ├── Public Subnet B  — 10.22.2.0/24
        └── Private Subnet B — 10.22.12.0/24
```

The environment now provides the networking foundation needed to distribute workloads across multiple Availability Zones.

---

# 8. Technical Concepts

## 8.1 Availability Zones

An AWS Region contains multiple physically separate Availability Zones.

Deploying infrastructure across more than one Availability Zone reduces dependency on a single AZ and provides the foundation for higher availability.

---

## 8.2 Subnets Are Availability-Zone Specific

A VPC spans an AWS Region, but an individual subnet belongs to only one Availability Zone.

Therefore, supporting workloads across two Availability Zones requires separate subnets:

```text
AZ-A → Public A + Private A

AZ-B → Public B + Private B
```

---

## 8.3 Multi-AZ Networking vs. Multi-AZ Workloads

Creating subnets across two Availability Zones does not automatically make an application highly available.

This phase creates the **network foundation** required for high availability.

For example:

```text
Multi-AZ VPC
     │
     ├── AZ-A
     │    └── Application Server A
     │
     └── AZ-B
          └── Application Server B
```

The actual compute, database, or application resources must also be distributed across the Availability Zones to provide workload-level resiliency.

---

## 8.4 Route Table Reuse

Multiple subnets can be associated with the same route table.

In this architecture:

```text
Public A ─┐
          ├── Public Route Table
Public B ─┘

Private A ─┐
           ├── Private Route Table
Private B ─┘
```

This provides consistent routing behavior across both Availability Zones.

---

## 8.5 Network ACL Associations

Network ACLs operate at the subnet level.

Adding new subnets therefore requires ensuring that those subnets are associated with the appropriate Network ACL.

The resulting design is:

```text
Public NACL
├── Public Subnet A
└── Public Subnet B

Private NACL
├── Private Subnet A
└── Private Subnet B
```

This extends the subnet-level security controls created in Phase 04 across both Availability Zones.

---

# 9. Security Consierations

The Phase 05 Multi-AZ expansion extends the existing network architecture into a second Availability Zone while maintaining the security boundaries established in the previous networking phases.

The addition of Public Subnet B and Private Subnet B does not introduce a new security model. Instead, the existing public and private network controls are extended consistently across both Availability Zones.

## 9.1 Public and Private Subnet Separation

Public and private subnet separation remains intact across both Availability Zones.

The resulting network contains:

* Public Subnet A in Availability Zone A.
* Private Subnet A in Availability Zone A.
* Public Subnet B in Availability Zone B.
* Private Subnet B in Availability Zone B.

This maintains the existing tiered network design:

```text
Public Tier
├── Public Subnet A — AZ-A
└── Public Subnet B — AZ-B

Private Tier
├── Private Subnet A — AZ-A
└── Private Subnet B — AZ-B
```

Resources requiring public-facing network connectivity can be deployed within the public tier, while databases and other internal resources can remain within the private tier.

---

## 9.2 Public Network ACL Protection

The public Network ACL created in Phase 24 is extended to include Public Subnet B.

The public NACL is therefore associated with:

```text
Public NACL
├── Public Subnet A — AZ-A
└── Public Subnet B — AZ-B
```

This ensures that the subnet-level traffic controls established for the public network tier are applied consistently across both Availability Zones.

A separate public NACL is not required simply because a second Availability Zone was introduced.

---

## 9.3 Private Network ACL Protection

The private Network ACL created in Phase 24 is also extended to include Private Subnet B.

The private NACL is associated with:

```text
Private NACL
├── Private Subnet A — AZ-A
└── Private Subnet B — AZ-B
```

This ensures that both private subnets receive the same subnet-level traffic controls.

The database and other private workloads that may later be deployed across the two Availability Zones therefore remain within the same private network security tier.

---

## 9.4 Existing NACL Rules Remain Consistent

Adding Availability Zone B does not require duplicating the individual NACL rules established in Phase 24.

Instead, the existing NACL resources are associated with the additional subnets:

```hcl
subnet_ids = [
  aws_subnet.public_a.id,
  aws_subnet.public_b.id
]
```

and:

```hcl
subnet_ids = [
  aws_subnet.private_a.id,
  aws_subnet.private_b.id
]
```

This allows the same public-tier and private-tier NACL policies to be applied consistently across Availability Zones.

The security policy therefore remains organized by **network tier** rather than by Availability Zone.

---

## 9.5 Route Table Separation

The Multi-AZ expansion preserves the existing public and private routing boundaries.

Public Subnet B is associated with the existing public route table:

```text
Public Subnet A ─┐
                 ├── Public Route Table ── Internet Gateway
Public Subnet B ─┘
```

Private Subnet B is associated with the existing private route table:

```text
Private Subnet A ─┐
                  ├── Private Route Table
Private Subnet B ─┘
```

This ensures that adding the second Availability Zone does not unintentionally give the private network tier the routing characteristics of the public tier.

Route tables control where network traffic is directed; they are part of the network segmentation design, while NACLs and Security Groups provide traffic filtering controls.

---

## 9.6 Consistent Security Controls Across Availability Zones

Expanding infrastructure across Availability Zones should preserve the same security posture for equivalent network tiers.

The architecture therefore follows two separate organizational boundaries:

**Availability boundary**

```text
AZ-A
├── Public Subnet A
└── Private Subnet A

AZ-B
├── Public Subnet B
└── Private Subnet B
```

**Security boundary**

```text
Public Tier
├── Public Subnet A
└── Public Subnet B

Private Tier
├── Private Subnet A
└── Private Subnet B
```

This distinction is important because Availability Zones provide infrastructure isolation and resiliency, while the public/private tiers define the network's security and routing boundaries.

---

## 9.7 Security Groups Remain a Separate Control Layer

The NACL changes introduced during the Multi-AZ expansion do not replace the Security Groups established in Phase 23.

The environment continues to use defense in depth:

```text
Route Tables
     │
     ▼
Network ACLs
     │
     ▼
Security Groups
     │
     ▼
AWS Resources
```

Each control serves a different purpose:

* **Route tables** determine where network traffic can be routed.
* **Network ACLs** provide stateless subnet-level traffic filtering.
* **Security Groups** provide stateful resource-level traffic filtering.

The Multi-AZ expansion preserves these security layers while making the additional AZ-B subnets available for future workloads.

---

## 9.8 Final Multi-AZ Security Architecture

The completed Phase 05 network security architecture is:

```text
                         AWS Region
                              │
                    VPC 10.22.0.0/16
                              │
          ┌───────────────────┴───────────────────┐
          │                                      │
 Availability Zone A                    Availability Zone B
          │                                      │
    ┌─────┴─────┐                          ┌─────┴─────┐
    │           │                          │           │
 Public A    Private A                  Public B    Private B
10.22.1.0/24 10.22.11.0/24           10.22.2.0/24 10.22.12.0/24
    │           │                          │           │
    │           │                          │           │
    └───────────┼──────────────────────────┼───────────┘
                │                          │
        Tier-Based Network Controls
                │
       ┌────────┴────────┐
       │                 │
   PUBLIC TIER       PRIVATE TIER
       │                 │
       ├─ Public A       ├─ Private A
       └─ Public B       └─ Private B
       │                 │
 Public Route Table   Private Route Table
       │                 │
 Public NACL          Private NACL
       │                 │
 Security Groups      Security Groups
       │                 │
 Public Workloads     Private Workloads
```

The key security principle demonstrated by this architecture is:

> **Availability is organized by Availability Zone, while network security controls remain organized by network tier.**

The second Availability Zone therefore increases the network's capacity to support resilient workloads without creating a separate or weaker security model for AZ-B.

Public Subnet A and Public Subnet B remain governed by the public-tier routing and NACL controls, while Private Subnet A and Private Subnet B remain governed by the private-tier routing and NACL controls.

This maintains consistent network segmentation and defense-in-depth controls across the Multi-AZ VPC architecture.

---

# 10. Cost Considerations

Extending the VPC into a second Availability Zone does not, by itself, introduce additional hourly infrastructure charges.

The following components used in this phase do not have a direct hourly charge:

* VPC
* Subnets
* Route tables
* Route table associations
* Network ACLs
* Network ACL associations

However, resources later deployed into the Multi-AZ architecture may introduce costs.

Examples include:

* NAT Gateways
* EC2 instances
* Public IPv4 addresses
* Application Load Balancers
* RDS database instances
* RDS Multi-AZ deployments
* Cross-Availability-Zone data transfer in scenarios where AWS data-transfer charges apply

Therefore, **Multi-AZ networking should not be confused with deploying paid Multi-AZ services**.

---

# 11. Troubleshooting

No significant issues were encountered during this phase. Potential configuration issues include overlapping CIDR blocks, incorrect Availability Zone assignments, missing route-table associations, and missing NACL subnet associations.

---

# 12. Lessons Learned

Extending a VPC into another Availability Zone requires more than creating additional subnets. Routing and subnet-level security associations must also be extended to the new subnets.

Multi-AZ networking provides the foundation for high availability but does not make workloads highly available by itself. Compute and database resources must also be distributed across Availability Zones.

---

# 13. Phase Completion

Phase 05 successfully expanded the custom VPC into a two-Availability-Zone network architecture.

The VPC now contains:

* Two public subnets across two Availability Zones.
* Two private subnets across two Availability Zones.
* Shared public routing for both public subnets.
* Shared private routing for both private subnets.
* Public NACL protection across both public subnets.
* Private NACL protection across both private subnets.
* Terraform outputs for the additional subnet IDs.

The network is now prepared for later phases that introduce additional production-style AWS networking and database infrastructure.

**Phase 05 Status: Complete — Multi-AZ Networking Established**
