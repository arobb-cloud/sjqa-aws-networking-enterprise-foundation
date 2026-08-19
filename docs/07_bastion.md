# Phase 07 — Bastion Host Architecture

## 1. Purpose

The purpose of this phase was to design a secure administrative access pattern for resources located within the private tier of the AWS network.

A bastion host, also known as a jump host, provides a controlled entry point into the VPC. Rather than exposing private resources directly to the internet, an administrator first connects to the bastion host in a public subnet and then uses that host to access authorized resources in private subnets.

The intended management path is:

```text
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnet
    │
    ▼
Bastion Host
    │
    ▼
Private Subnet
    │
    ▼
Private EC2 / Future RDS PostgreSQL
```

This phase was implemented in Terraform but was not deployed. The bastion configuration remains in the active Terraform codebase and is disabled by default through the `enable_bastion` feature flag.

---

## 2. Objectives

The objectives of this phase were to:

1. Define an SSH key-pair variable for bastion authentication.
2. Dynamically retrieve a current Amazon Linux 2023 AMI.
3. Define configurable SSH access to the management security group using an administrator-supplied CIDR range.
4. Define an EC2 bastion host within the public subnet.
5. Assign a public IP address to the bastion host.
6. Create Terraform outputs for the bastion instance ID and public IP address.
7. Validate the Terraform configuration with the bastion feature disabled by default.
8. Preserve the bastion configuration for future implementation.

---

## 3. Architecture

The bastion host was designed to reside in the public subnet created during the earlier VPC networking phases.

Its purpose is to act as an administrative gateway between an external administrator and resources that should remain inaccessible directly from the public internet.

```text
                         Internet
                            │
                            │ SSH :22
                            ▼
                    Internet Gateway
                            │
                            ▼
              ┌─────────────────────────┐
              │      Public Subnet      │
              │                         │
              │   ┌─────────────────┐   │
              │   │  Bastion Host   │   │
              │   │  Amazon Linux   │   │
              │   │  Public IP      │   │
              │   └────────┬────────┘   │
              └────────────│────────────┘
                           │
                     Management Path
                           │
                           ▼
              ┌─────────────────────────┐
              │      Private Subnet     │
              │                         │
              │   Private Resources     │
              │   Future PostgreSQL     │
              │   Future Application    │
              │   Infrastructure        │
              └─────────────────────────┘
```

The design preserves the public/private subnet boundary established in previous phases. Private resources do not require public IP addresses merely to support administrative access.

---

## 4. Terraform Configuration

### 4.1 Define Bastion Configuration Variables

The following variables were added to `variables.tf`:

```hcl
variable "enable_bastion" {
  description = "Controls whether the EC2 bastion host is deployed"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for bastion access"
  type        = string
  default     = null
}

variable "bastion_allowed_cidr" {
  description = "IPv4 CIDR permitted to SSH to the bastion host"
  type        = string
  default     = null
}
```

These variables control whether the bastion infrastructure is created, supply the name of an existing EC2 key pair for SSH authentication, and define the IPv4 CIDR permitted to initiate SSH connections. With `enable_bastion` set to `false`, the bastion-related resources are not created.

---

### 4.2 Create the Bastion Terraform Configuration

A new Terraform configuration was prepared:

```text
terraform/bastion.tf
```

The Amazon Linux 2023 AMI is retrieved dynamically:

```hcl
data "aws_ami" "amazon_linux_2023" {
  count = var.enable_bastion ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}
```

Using an AMI data source avoids hard-coding a specific AMI ID, which can vary by AWS Region and become outdated over time.

---

### 4.3 Define Bastion SSH Access

The following ingress rule was designed for the existing management security group:

```hcl
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_from_internet" {
  count = var.enable_bastion ? 1 : 0

  security_group_id = aws_security_group.management.id

  cidr_ipv4   = var.bastion_allowed_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Allow SSH to bastion host"
}
```

This rule permits SSH connections to the bastion host.

> **Security Note:** The permitted SSH source is supplied through `bastion_allowed_cidr`. When the bastion is enabled, this value should be restricted to an approved administrative public IP address or trusted CIDR range. A value such as `0.0.0.0/0` would expose TCP port 22 to the entire IPv4 internet and should not be used for production access.

---

### 4.4 Define the Bastion EC2 Instance

The following EC2 resource was prepared:

```hcl
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2023[0].id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.management.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion"
    Project     = var.project_name
    Environment = var.environment
    Tier        = "Management"
  }
}
```

The bastion host was designed to:

* Run Amazon Linux 2023.
* Reside in the public subnet.
* Receive a public IPv4 address.
* Use the existing management security group.
* Authenticate through an EC2 key pair.
* Provide a controlled management entry point into the VPC.

---

### 4.5 Define Terraform Outputs

The following outputs were added to `outputs.tf`:

```hcl
output "bastion_instance_id" {
  description = "EC2 instance ID of the bastion host when enabled."
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host when enabled."
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}
```

These outputs would expose the EC2 instance ID and public IP address following deployment.

---

## 5. Deployment

The bastion host was **not deployed during this phase**.

The Terraform resources were intentionally retained as a future architecture component rather than applying the configuration and maintaining an active EC2 instance.

The bastion configuration remains in `terraform/bastion.tf` as part of the project's active Terraform codebase. Deployment is controlled through the `enable_bastion` variable, which defaults to `false`.

With the default configuration, Terraform does not create the bastion AMI lookup, SSH ingress rule, or EC2 instance because each bastion component uses the conditional expression `count = var.enable_bastion ? 1 : 0`.

This approach preserves the architecture for future use while preventing the bastion host from being provisioned during normal project validation.

No `terraform apply` was performed for the bastion host.

---

## 6. Validation

The repository has been formatted, validated, and planned with the bastion feature disabled. Because `enable_bastion` defaults to `false`, the normal Terraform plan does not propose creation of the bastion EC2 instance or its associated SSH ingress rule.

```powershell
terraform fmt
terraform validate
terraform plan -out=tfplan
```

The purpose of these commands was to verify:

* Terraform formatting.
* Configuration syntax and internal references.
* Resource dependencies.
* The infrastructure changes Terraform would propose before deployment.

Because `terraform apply` was not executed, no bastion EC2 instance was created in AWS.

A screenshot of the validation/planning process was retained with the project documentation as supporting evidence.

---

## 7. Expected AWS Resources

If this phase were deployed, the configuration would introduce the following primary AWS components:

| Component                              | Role                                        |
| -------------------------------------- | ------------------------------------------- |
| Amazon EC2 Bastion Host                | Administrative entry point into the VPC     |
| Amazon Linux 2023 AMI lookup           | Selects an existing AWS-provided AMI        |
| Public IPv4 Address                    | Enables public connectivity to the bastion  |
| Management Security Group ingress rule | Restricts SSH access to the configured CIDR |
| Existing EC2 Key Pair                  | Provides SSH authentication when supplied   |
| Existing Public Subnet                 | Hosts the bastion instance                  |


The bastion would reuse networking and security components created during previous project phases rather than creating a separate network architecture.

---

## 8. Cost Considerations

The bastion host architecture introduces costs associated with operating an EC2 instance and potentially other AWS networking resources.

Because the bastion host was not required for continuous operation during this portfolio build, the instance was not deployed.

For a temporary project environment, a bastion could be created only when administrative access is required and destroyed afterward.

A production environment should also evaluate whether a traditional bastion host is necessary. AWS Systems Manager Session Manager can provide managed administrative access to supported EC2 instances without requiring inbound SSH access or a publicly accessible bastion host.

---

## 9. Security Considerations

The bastion architecture improves network segmentation by providing a defined management path rather than exposing private resources directly to the internet.

The following security principles apply:

1. **Private resources remain private.**
   Resources within private subnets should not receive public IP addresses solely for administrative access.

2. **SSH access should be tightly restricted.**
   The project configuration specifies:

   ```hcl
   cidr_ipv4 = var.bastion_allowed_cidr
   ```

   The security of this rule depends on the value supplied through `bastion_allowed_cidr`. When the bastion is enabled, the variable should be set to an approved administrator public IP address or trusted CIDR range. A broad value such as `0.0.0.0/0` would expose SSH to the entire IPv4 internet and should not be used for production access.

3. **The bastion should use a dedicated management security group.**
   Management access should remain separate from application and database traffic.

4. **Private-tier security groups should trust specific sources rather than the internet.**
   Administrative access to private EC2 resources should originate from the bastion's security group or another explicitly authorized management source.

5. **Database access should remain application-specific.**
   A bastion host should not automatically receive unrestricted PostgreSQL access merely because it is part of the management tier. Database connectivity should be granted only when an administrative requirement exists.

6. **SSH keys must not be stored in the repository.**
   Private key material must never be committed to GitHub or embedded within Terraform configuration.

7. **Administrative access should be logged and monitored.**
   A production implementation should incorporate appropriate operating-system logging, CloudTrail where applicable, and centralized monitoring.

8. **Session Manager should be considered for production designs.**
   AWS Systems Manager Session Manager can reduce the attack surface by removing the need for inbound SSH and public bastion exposure where the architecture supports it.

---

## 10. Troubleshooting Considerations

If the bastion host were deployed but SSH connectivity failed, troubleshooting should proceed through each layer of the connection path:

```text
Administrator
     │
     ▼
Public Internet
     │
     ▼
Internet Gateway
     │
     ▼
Public Route Table
     │
     ▼
Public Subnet
     │
     ▼
Network ACL
     │
     ▼
Management Security Group
     │
     ▼
Bastion EC2 Instance
```

Items to verify would include:

* The EC2 instance is running.
* The bastion has a public IPv4 address.
* The public subnet has a route to the Internet Gateway.
* TCP port 22 is permitted by the management security group.
* The public subnet NACL permits the required inbound and return traffic.
* The correct EC2 key pair is being used.
* The private key has the appropriate local permissions.
* The Amazon Linux SSH username is correct.
* Any downstream private resource permits traffic from the intended management source.

This layered troubleshooting approach helps isolate whether a connectivity failure originates from routing, subnet controls, security groups, authentication, or the operating system.

---

## 11. Lessons Learned

This phase demonstrated that secure administrative access is an architectural concern that should be designed separately from application and database connectivity.

Key lessons include:

* A bastion host provides a controlled entry point into private network tiers.
* Public IP addresses do not need to be assigned to every resource that requires administration.
* Security groups can be used to define trusted management relationships between tiers.
* Open SSH access such as `0.0.0.0/0` is inappropriate for production environments.
* Terraform feature flags can retain optional infrastructure in the main configuration while preventing deployment until the capability is explicitly enabled.
* Cost-conscious project environments do not need to keep management infrastructure running continuously.
* Modern AWS architectures may replace traditional SSH bastion patterns with Systems Manager Session Manager to reduce public exposure and key-management requirements.

---

## 12. Phase Outcome

**Status: Implemented in Terraform — disabled by default; deployment deferred.**

Phase 07 established the Terraform design for a bastion-host management architecture but did not provision the EC2 instance.

The phase demonstrated how administrative access could be routed through a controlled public management host while preserving the isolation of private resources.

The Terraform configuration remains in `terraform/bastion.tf` and is controlled through the `enable_bastion` feature flag. Because the variable defaults to `false`, the bastion host is not created during the project's normal Terraform workflow.

This leaves the network architecture prepared for future private-resource administration without incurring the cost or security exposure of maintaining an unnecessary public EC2 management host during the current project stage.
