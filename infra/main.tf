# Identidade da conta AWS atual
data "aws_caller_identity" "current" {}

# Última AMI Ubuntu 22.04 oficial
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group da EC2
resource "aws_security_group" "app" {
  name        = "batponto-dev-ec2-sg"
  description = "EC2 app server SG"
  vpc_id      = var.vpc_id
}

# Libera HTTP público
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# Libera SSH apenas do IP permitido
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

# Libera saída para qualquer destino
resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Policy para EC2 assumir role
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals { 
      type = "Service"
      identifiers = ["ec2.amazonaws.com"] 
    }
  }
}

# Role da EC2
resource "aws_iam_role" "ec2_role" {
  name               = "batponto-dev-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Permite pull de imagens do ECR
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Policy para ler secrets do banco
data "aws_iam_policy_document" "secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.db_secret_arn]
  }
}

# Policy de acesso ao Secrets Manager
resource "aws_iam_policy" "secrets" {
  name   = "batponto-dev-secrets-read"
  policy = data.aws_iam_policy_document.secrets.json
}

# Anexa policy de secrets à role
resource "aws_iam_role_policy_attachment" "secrets_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets.arn
}

# Instance profile para EC2 usar a role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "batponto-dev-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Script de inicialização da EC2
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Atualiza sistema e instala dependências básicas
    apt-get update -y
    apt-get install -y ca-certificates curl jq unzip

    # Instala AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    # Instala Docker e Docker Compose
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # Diretório da aplicação
    mkdir -p /opt/batponto
    cd /opt/batponto

    # Login no ECR
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com

    # Lê credenciais do banco no Secrets Manager
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${var.db_secret_arn}" --region us-east-1 --query SecretString --output text)
    DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
    DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

    # Arquivo .env com dados do banco
    cat > .env <<ENV
    DB_HOST=${var.db_host}
    DB_PORT=${var.db_port}
    DB_NAME=${var.db_name}
    DB_USER=$DB_USER
    DB_PASSWORD=$DB_PASSWORD
    ENV

    # Docker Compose da aplicação
    cat > docker-compose.yml <<'YAML'
    services:
      flyway:
        image: ${var.flyway_image}
        env_file: [.env]
        restart: "no"

      backend:
        image: ${var.backend_image}
        env_file: [.env]
        depends_on:
          flyway:
            condition: service_completed_successfully
        environment:
          SPRING_DATASOURCE_URL: jdbc:postgresql://$${DB_HOST}:$${DB_PORT}/$${DB_NAME}?sslmode=require
          SPRING_DATASOURCE_USERNAME: $${DB_USER}
          SPRING_DATASOURCE_PASSWORD: $${DB_PASSWORD}
          SERVER_PORT: 8080
        restart: unless-stopped

      frontend:
        image: ${var.frontend_image}
        ports:
          - "80:80"
        depends_on:
          - backend
        restart: unless-stopped
    YAML

    # Sobe os containers
    docker compose pull
    docker compose up -d
  EOF
}

# EC2 da aplicação
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_pair_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = { Name = "batponto-dev-app" }
}

# Elastic IP fixo
resource "aws_eip" "app" {
  domain = "vpc"
  tags   = { Name = "batponto-dev-eip" }
}

# Associa EIP à EC2
resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}