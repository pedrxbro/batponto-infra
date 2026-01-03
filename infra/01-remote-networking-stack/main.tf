# Nome base para recursos de rede
locals {
  name = "${var.project}-${var.environment}"
}

# Cria a VPC principal
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Internet Gateway para acesso à internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# Subnets públicas (com IP público)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[0]
  cidr_block              = "10.0.0.0/26"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.azs[1]
  cidr_block              = "10.0.0.64/26"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-b"
    Tier = "public"
  }
}

# Subnets privadas (sem acesso à internet)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[0]
  cidr_block        = "10.0.0.128/26"

  tags = {
    Name = "${local.name}-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[1]
  cidr_block        = "10.0.0.192/26"

  tags = {
    Name = "${local.name}-private-b"
    Tier = "private"
  }
}

# Route table pública com saída pela Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associa subnets públicas à route table pública
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Route table privada (sem rota para internet)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-private" }
}

# Associa subnets privadas à route table privada
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}