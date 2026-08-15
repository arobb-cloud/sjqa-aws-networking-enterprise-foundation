resource "aws_eip" "nat_a" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip-a"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat_a" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat_a[0].id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-a"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a[0].id
}
