# Phase 06 — NAT Gateway Architecture

## 1. Purpose

The purpose of this phase is to design outbound Internet connectivity for resources located in the private subnet while preserving the network's public/private isolation model.

A NAT Gateway allows resources in a private subnet to initiate outbound connections to the Internet without allowing unsolicited inbound Internet connections directly to those resources.

Typical use cases include:

* Operating system package updates
* Application dependency downloads
* Access to external APIs
* Software installation and patching
* Outbound communication from private EC2 instances
* Access to AWS public service endpoints when VPC endpoints are not being used

For this project, the NAT Gateway architecture was designed and represented in Terraform but was **not deployed** because the managed NAT Gateway service would introduce ongoing AWS charges.

---

## 2. Objectives

The objectives of this phase were to:

1. Understand the purpose of a NAT Gateway within a public/private subnet architecture.
2. Design outbound Internet connectivity for the private subnet.
3. Allocate a public Elastic IP address for the NAT Gateway.
4. Place the NAT Gateway in the public subnet.
5. Configure the private route table to send Internet-bound traffic through the NAT Gateway.
6. Preserve the existing separation between public and private network tiers.
7. Represent the proposed architecture using Terraform.
8. Evaluate the cost implications before deployment.
9. Avoid unnecessary charges in the portfolio/project environment.

---

## 3. Architecture Overview

The NAT Gateway would provide an outbound path from resources in the private subnet to the Internet.

The intended traffic flow is:

```text
                         Internet
                            │
                            ▼
                    Internet Gateway
                            │
                     Public Subnet A
                       10.22.1.0/24
                            │
                    ┌───────────────┐
                    │  NAT Gateway  │
                    │   + EIP       │
                    └───────────────┘
                            ▲
                            │
                  0.0.0.0/0 Route
                            │
                   Private Route Table
                            │
                     Private Subnet A
                       10.22.2.0/24
                            │
                    ┌───────────────┐
                    │ Private AWS   │
                    │ Resources     │
                    └───────────────┘
```

The important architectural distinction is that the NAT Gateway does **not** make the private subnet public.

Resources in the private subnet would continue to have no direct route to the Internet Gateway. Instead, Internet-bound traffic would be forwarded to the NAT Gateway located in the public subnet.

The NAT Gateway would then translate the private source address to its associated Elastic IP address before sending traffic through the Internet Gateway.

Return traffic would follow the established NAT session back to the originating private resource.

---

## 4. Terraform Configuration

### 4.1 Create the NAT Gateway Terraform File

A dedicated Terraform file was planned for the NAT Gateway configuration:

```powershell
New-Item nat_gateway.tf
```

The file separates NAT-related resources from the existing VPC, subnet, routing, and security configuration.

---

### 4.2 Allocate an Elastic IP Address

The following Terraform resource would allocate an Elastic IP address for the NAT Gateway:

```hcl
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip-a"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

The Elastic IP provides the NAT Gateway with a stable public IPv4 address for outbound Internet communication.

Private resources would not receive this address directly. Their outbound connections would instead be translated through the NAT Gateway.

---

### 4.3 Create the NAT Gateway

The following resource would create the NAT Gateway inside Public Subnet A:

```hcl
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-a"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}
```

The NAT Gateway must reside in a **public subnet** because it requires connectivity through the Internet Gateway.

The configuration references:

* The Elastic IP allocated by `aws_eip.nat_a`
* Public Subnet A created during the VPC networking phases
* The existing Internet Gateway

The explicit `depends_on` ensures that the Internet Gateway exists before Terraform attempts to provision the NAT Gateway.

---

### 4.4 Configure the Private Default Route

The private route table would receive a default route directing Internet-bound traffic to the NAT Gateway:

```hcl
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}
```

The resulting private route table would conceptually contain:

```text
Destination       Target
----------------  -------------------------
10.22.0.0/16      local
0.0.0.0/0         NAT Gateway
```

This configuration is fundamentally different from the public route table.

The public route table uses:

```text
0.0.0.0/0 → Internet Gateway
```

The private route table would use:

```text
0.0.0.0/0 → NAT Gateway
```

This distinction preserves the private nature of the subnet while allowing resources to initiate outbound Internet connections.

---

### 4.5 Add Terraform Outputs

The following outputs were planned to expose the NAT Gateway ID and public Elastic IP address:

```hcl
output "nat_gateway_id" {
  value = aws_nat_gateway.nat_a.id
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat_a.public_ip
}
```

These outputs would make it easier to verify the deployed NAT Gateway and identify its associated public IP address after deployment.

---

## 5. Planned Deployment

Under a production or fully deployed project scenario, the NAT Gateway configuration would be deployed using the standard Terraform workflow:

```powershell
terraform fmt
terraform validate
terraform plan
terraform apply
```

Terraform would be expected to create:

```text
Elastic IP
    │
    ▼
NAT Gateway
    │
    ▼
Private Default Route
```

The private subnet's route table would then direct `0.0.0.0/0` traffic to the NAT Gateway.

### Deployment Status

**Not Deployed — Cost-Control Decision**

The NAT Gateway resources were intentionally not provisioned in AWS.

The configuration was retained as an architectural design and Terraform implementation reference to demonstrate how private subnet outbound Internet access would be implemented in a production-style environment.

This decision prevented unnecessary recurring infrastructure charges in a portfolio environment where continuous outbound connectivity from private resources was not required.

---

## 6. Validation

Because the NAT Gateway was intentionally not deployed, AWS Console runtime validation was **not performed** for this phase.

Validation for this phase should therefore be distinguished between configuration validation and deployment validation.

### Terraform Configuration Validation

The proposed configuration can be reviewed for the following relationships:

```text
aws_eip.nat_a
        │
        ▼
aws_nat_gateway.nat_a
        │
        ▼
aws_route.private_nat
        │
        ▼
aws_route_table.private
```

The design confirms that:

1. An Elastic IP would be allocated for the NAT Gateway.
2. The NAT Gateway would be placed in the public subnet.
3. The NAT Gateway would depend on the Internet Gateway.
4. The private route table would use the NAT Gateway as its default Internet route.
5. Private resources would not receive a direct Internet Gateway route.

### Runtime Validation Not Performed

The following checks would normally be performed after deployment:

* Verify the NAT Gateway reaches the `Available` state.
* Verify the Elastic IP is associated with the NAT Gateway.
* Verify the NAT Gateway resides in the intended public subnet.
* Verify the private route table contains `0.0.0.0/0 → NAT Gateway`.
* Verify the public subnet contains `0.0.0.0/0 → Internet Gateway`.
* Launch or use a resource without a public IP address in the private subnet.
* Verify that the private resource can initiate outbound Internet connections.
* Verify that unsolicited inbound Internet connections cannot directly reach the private resource.

These runtime tests were not performed because the NAT Gateway was not provisioned.

---

## 7. Cost Considerations

Cost was the primary reason for not deploying the NAT Gateway in this project.

Unlike many basic VPC networking constructs such as route tables and Internet Gateways, a managed NAT Gateway introduces charges while it is provisioned and can also incur data-processing charges as traffic passes through it.

For a short-lived production test this may be acceptable, but maintaining the resource solely for portfolio demonstration would create unnecessary cost.

The project therefore follows the principle:

> **Design the production-capable architecture, understand how it would be deployed, but do not maintain billable infrastructure when it provides no additional portfolio or learning value.**

This decision also demonstrates an important cloud engineering principle: architecture decisions should account for **cost alongside availability, security, performance, and operational requirements**.

---

## 8. Security Considerations

The NAT Gateway architecture preserves the existing public/private subnet security boundary.

### Private Resources Remain Private

Adding a NAT Gateway does not assign public IP addresses to resources in the private subnet.

Private resources would continue to communicate externally through:

```text
Private Resource
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

Inbound Internet traffic cannot use the NAT Gateway as a general-purpose connection path to initiate sessions with private resources.

### Internet Gateway Isolation

The private subnet should not receive a direct route such as:

```text
0.0.0.0/0 → Internet Gateway
```

Doing so would violate the intended network architecture.

Instead, the private default route should point to:

```text
0.0.0.0/0 → NAT Gateway
```

### Security Groups Remain Required

The NAT Gateway does not replace Security Groups.

Security Groups continue to enforce resource-level traffic controls for application servers, databases, management systems, and future workloads.

### Network ACLs Remain Required

The public and private Network ACLs configured during the previous security phase continue to provide subnet-level controls.

Because Network ACLs are stateless, appropriate outbound and return-path rules must continue to exist for traffic traversing the NAT architecture.

### Database Exposure

Database resources should not depend on NAT connectivity for inbound application access.

Application-to-database communication should continue to occur over private VPC addressing and be controlled through Security Groups and subnet-level controls.

The NAT Gateway should primarily support **outbound connectivity**, not provide a mechanism for exposing private database resources to the Internet.

---

## 9. Troubleshooting Considerations

Because the NAT Gateway was not deployed, the following items represent expected troubleshooting procedures for a future deployment.

### NAT Gateway Has No Internet Connectivity

Verify that:

```text
NAT Gateway
    │
    ├── Located in public subnet
    ├── Has Elastic IP
    ├── Public subnet route table has 0.0.0.0/0 → Internet Gateway
    └── Internet Gateway is attached to VPC
```

A NAT Gateway located in a private subnet would not provide the intended Internet access.

### Private Resource Cannot Reach the Internet

Verify the private route table contains:

```text
0.0.0.0/0 → NAT Gateway
```

Also verify:

* The private subnet is associated with the correct private route table.
* Security Group outbound rules permit the required traffic.
* Network ACL outbound rules permit the traffic.
* Network ACL inbound rules permit the corresponding return traffic.

### NAT Gateway Cannot Be Created

Verify that:

* The referenced subnet exists.
* The Elastic IP was successfully allocated.
* The Internet Gateway exists.
* The resources are located in compatible VPC networking constructs.

### Unexpected Public Exposure

Verify that private resources:

* Do not have public IPv4 addresses.
* Are not associated with the public route table.
* Do not have `0.0.0.0/0 → Internet Gateway`.
* Have appropriately restrictive Security Groups.
* Remain associated with the intended private subnet and private NACL.

---

## 10. Lessons Learned

This phase demonstrated several important AWS networking concepts.

### NAT Does Not Make a Private Subnet Public

A NAT Gateway allows private resources to initiate outbound connections while maintaining the absence of direct inbound Internet connectivity.

The direction of communication is important:

```text
Private → Internet     Allowed through NAT
Internet → Private     Not initiated through NAT
```

### Route Tables Determine the Traffic Path

A subnet is not considered public or private simply because of its name.

The routing configuration determines its network behavior.

For this architecture:

```text
Public Subnet
0.0.0.0/0 → Internet Gateway

Private Subnet
0.0.0.0/0 → NAT Gateway
```

### NAT Gateways Belong in Public Subnets

The NAT Gateway requires Internet Gateway connectivity and therefore must be deployed in a public subnet.

The private subnet sends traffic **to** the NAT Gateway but does not contain the NAT Gateway itself.

### Cost Is an Architectural Consideration

Not every technically valid resource needs to remain deployed in this project environment.

The NAT Gateway configuration was intentionally documented rather than provisioned because the additional runtime cost was unnecessary for demonstrating the architectural concept.

### Documentation Can Capture Undeployed Production Design

A portfolio project can demonstrate knowledge of an AWS architecture even when a billable resource is intentionally excluded, provided that the documentation clearly identifies:

* What the resource does
* Where it belongs
* How it integrates with existing infrastructure
* How it would be implemented
* How it would be validated
* Why it was not deployed

This distinguishes a deliberate engineering decision from an incomplete implementation.

---

## 11. Final Architecture State

At the completion of Phase 06, the **implemented** environment remains:

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
              10.22.1.0/24                 10.22.3.0/24
                    │                           │
                    └──────── Public Tier ──────┘


             Private Subnet A             Private Subnet B
               us-east-1a                   us-east-1b
              10.22.2.0/24                 10.22.4.0/24
                    │                           │
                    └──────── Private Tier ─────┘
```

The **planned production NAT architecture** would extend the environment as follows:

```text
                              Internet
                                  │
                                  ▼
                         Internet Gateway
                                  │
                                  ▼
                         Public Subnet A
                                  │
                           ┌─────────────┐
                           │ NAT Gateway │
                           │    + EIP    │
                           └──────┬──────┘
                                  ▲
                                  │
                           0.0.0.0/0
                                  │
                       Private Route Table
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
             Private Subnet A             Private Subnet B
                    │                           │
                    ▼                           ▼
              Private Workloads           Private Workloads
```

**Deployment status:** Designed and documented; NAT Gateway intentionally not provisioned for cost-control purposes.

This phase therefore completes the NAT Gateway architectural design while maintaining a cost-conscious portfolio environment.
