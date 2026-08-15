data "aws_ami" "amazon_linux_2023" {
  count = var.enable_bastion ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_from_internet" {
  security_group_id = aws_security_group.management.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "Allow SSH to bastion host"
}

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



