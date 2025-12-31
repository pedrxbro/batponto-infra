locals {
  name = "${var.project}-${var.environment}"
}

# Subnet group: SOMENTE privadas
resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnets"
  subnet_ids = var.private_subnet_ids

  # O RDS só pode ser criado em subnets privadas para não ficar exposto publicamente.

  tags = {
    Name = "${local.name}-db-subnets"
  }
}

# SG do RDS (Quem pode acessar o RDS)
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS PostgreSQL access"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name}-rds-sg"
  }
}

# Regra de entrada:
resource "aws_vpc_security_group_ingress_rule" "postgres_from_vpc" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = "10.0.0.0/24"
  description       = "Allow Postgres from VPC CIDR"

  # Permite que qualquer recurso dentro da VPC acesse o PostgreSQL.
  # Observação: pode ser refinado futuramente para permitir apenas o SG do EKS.
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
  # Permite que o RDS faça conexões de saída para qualquer destino, caso necessário.
}

# RDS PostgreSQL 16 com senha gerenciada no Secrets Manager
resource "aws_db_instance" "this" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username

  # Cria/gerencia a senha no Secrets Manager automaticamente
  manage_master_user_password = true

  # Rede
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Não precisa de alta disponibilidade, backups de 7 dias e permite deletar sem snapshot final
  multi_az               = false
  backup_retention_period = 7
  deletion_protection    = false
  skip_final_snapshot    = true

  # Atualiza automaticamente para pequenas versões
  auto_minor_version_upgrade = true

  tags = {
    Name = "${local.name}-postgres"
  }
}
