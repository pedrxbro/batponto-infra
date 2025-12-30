# Obtém informações da conta AWS atual
data "aws_caller_identity" "current" {}

# Variáveis locais para padronizar o nome do bucket
locals {
  bucket_name = "${var.project}-tfstate-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

# Cria o bucket S3 para armazenar o Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name
}

# Habilita versionamento do bucket
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Define criptografia padrão dos objetos no bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueia qualquer tipo de acesso público ao bucket
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
