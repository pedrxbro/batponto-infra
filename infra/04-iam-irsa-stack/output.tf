locals {
  name = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}

# Extrai o host do OIDC issuer (sem https://)
locals {
  oidc_host = replace(var.cluster_oidc_issuer, "https://", "")
}

# Busca o OIDC provider já criado no stack do EKS
data "aws_iam_openid_connect_provider" "eks" {
  url = var.cluster_oidc_issuer
}

# Documenta a política de assunção da role pelo ServiceAccount via OIDC
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"] 
    # Permite que o ServiceAccount assuma a role via token OIDC
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
      # Apenas tokens do OIDC do cluster podem assumir a role
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
      # Limita a assunção apenas para o ServiceAccount específico
    }
  }
}

# Cria a IAM Role que será usada pelo ServiceAccount no Kubernetes
resource "aws_iam_role" "irsa" {
  name               = "${local.name}-secrets-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Cria a policy para permitir acesso ao Secrets Manager
data "aws_iam_policy_document" "secrets_access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",   # Permite ler valor da secret
      "secretsmanager:DescribeSecret"    # Permite obter metadados da secret
    ]
    resources = [var.db_secret_arn]      # Apenas a secret do RDS especificado
  }
}

# Cria a policy na AWS
resource "aws_iam_policy" "secrets_access" {
  name   = "${local.name}-secrets-access"
  policy = data.aws_iam_policy_document.secrets_access.json
}

# Anexa a policy à IAM Role do ServiceAccount
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.irsa.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Exporta o ARN da role IRSA para usar em outros módulos ou no Kubernetes
output "irsa_role_arn" {
  value = aws_iam_role.irsa.arn
}
