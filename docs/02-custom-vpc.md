# Phase 02 — VPC and Core Network Infrastructure

## 1. Purpose

Establish the foundational AWS networking layer for the project using Terraform.

This phase creates the initial Virtual Private Cloud (VPC), public and private subnets, an Internet Gateway, route tables, routing configuration, and Terraform outputs required by later infrastructure phases.

## 2. Objectives

- Create a dedicated AWS VPC.
- Configure DNS support and DNS hostnames.
- Create an initial public subnet.
- Create an initial private subnet.
- Attach an Internet Gateway to the VPC.
- Configure public internet routing.
- Create separate public and private route tables.
- Associate each subnet with the appropriate route table.
- Expose important resource IDs through Terraform outputs.
- Validate the Terraform configuration before deployment.
- Deploy and verify the AWS networking resources.

## 3. Architecture / Design

The initial network uses the following CIDR structure:

- VPC: `10.22.0.0/16`
- Public subnet A: `10.22.1.0/24`
- Private subnet A: `10.22.11.0/24`

Both subnets are initially deployed into Availability Zone A for the configured AWS region.

The public subnet is configured to assign public IP addresses to resources launched within it. Internet access is provided through an Internet Gateway and a default route of `0.0.0.0/0`.

The private subnet is associated with a separate private route table and does not receive a direct route to the Internet Gateway.

This establishes the initial network boundary that later phases expand into a Multi-AZ architecture.

## 4. Resources Implemented

The following Terraform-managed AWS resources were introduced:

| Terraform Resource | Purpose |
|---|---|
| `aws_vpc.main` | Main project VPC |
| `aws_subnet.public_a` | Initial public subnet |
| `aws_subnet.private_a` | Initial private subnet |
| `aws_internet_gateway.main` | Provides internet connectivity to the VPC |
| `aws_route_table.public` | Routing table for public resources |
| `aws_route.public_internet` | Default route from public subnet to Internet Gateway |
| `aws_route_table_association.public_a` | Associates public subnet with public route table |
| `aws_route_table.private` | Routing table for private resources |
| `aws_route_table_association.private_a` | Associates private subnet with private route table |

## 5. Implementation

### Create `vpc.tf`

Created the Terraform configuration file:

#```powershell
New-Item vpc.tf

The file contains the initial VPC networking configuration:

resource "aws_vpc" "main" {
  cidr_block           = "10.22.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.22.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-a"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.22.11.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-a"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# Update outputs.tf

Terraform outputs were added so that important resource identifiers could be easily referenced after deployment and by later Terraform resources.

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_a.id
}

output "private_subnet_id" {
  value = aws_subnet.private_a.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

### 6. Deployment Procedure
Validate Terraform Configuration

The Terraform configuration was validated before deployment:
terraform validate

A Terraform execution plan was then generated:
terraform plan -out=tfplan

The plan was also exported to a text file for review and documentation:
terraform show tfplan > terraform-plan.txt

The generated terraform-plan.txt file was stored outside of the tracked source-code tree so that it would not be unintentionally committed to the GitHub repository.

# Update Source Control

The Terraform configuration changes were committed to Git:
git status
git add .
git commit -m "Updating file structure for Terraform"
git push -u origin main

Deploy AWS Resources

The previously generated Terraform plan was applied:
terraform apply tfplan

Using the saved plan ensured that Terraform applied the same infrastructure changes that were reviewed during the planning step.

### 7. Validation

After deployment, Terraform state was reviewed to confirm that the expected resources were under Terraform management:
terraform state list

Terraform outputs were then reviewed:
terraform output

Validation confirmed that the VPC, subnets, Internet Gateway, route tables, routes, and route-table associations were successfully created.

### 8. Outputs / Results

The deployment exposed the following Terraform outputs:

VPC ID
Public subnet ID
Private subnet ID
Public route table ID
Private route table ID

These outputs provide resource identifiers needed for later networking, security, compute, and database phases.

### 9. Security Considerations

The private subnet was intentionally created without a direct route to the Internet Gateway.

Only the public subnet was associated with a route table containing the following default route:

0.0.0.0/0 → Internet Gateway

This establishes separation between resources intended to be publicly reachable and resources intended to remain within the private network tier.

Additional network security controls are introduced in later phases.

### 10. Cost Considerations

The networking resources created in this phase—such as the VPC, subnets, route tables, and Internet Gateway attachment—do not by themselves represent the major cost drivers of the architecture.

Cost-sensitive networking components such as NAT Gateway architecture are evaluated separately in a later phase.

### 11. Troubleshooting / Issues Encountered

No major deployment issues were recorded for this phase.

The Terraform plan was exported for review, but the generated plan documentation was intentionally kept outside the Git-tracked code tree to avoid committing transient deployment artifacts.


### 12. Lessons Learned

This phase demonstrated several foundational AWS networking concepts:

A VPC establishes the private IP address boundary for AWS resources.
Public and private subnets can exist within the same VPC while using different routing behavior.
A subnet does not become public simply because it exists inside a VPC.
Public routing requires both an Internet Gateway and an appropriate route-table entry.
Route-table associations determine which routing policies apply to individual subnets.
Terraform outputs provide a clean mechanism for exposing infrastructure identifiers.
Reviewing a Terraform plan before applying infrastructure changes improves deployment predictability.


### 13. Phase Completion

Phase 22 successfully established the initial AWS networking foundation.

At completion, the environment contained:

One VPC
One public subnet
One private subnet
One Internet Gateway
Separate public and private route tables
Public internet routing
Terraform-managed subnet-to-route-table associations

This foundation was ready to support subsequent networking and security enhancements.


### What happened to your original numbered steps?

Nothing was lost. They were simply reorganized according to **what type of information they represent**.

Your original:

```text
1. Create VPC Terraform File
2. Add outputs
3. Validate Terraform backend
4. Update Github
5. Deploy the resources
6. Verify

