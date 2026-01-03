locals {
  # Nome padrão dos recursos: ex. batponto-dev
  name = "${var.project}-${var.environment}"
}

# --- IAM Role do Cluster ---
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]  # Permite que o EKS assuma este role
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]  # Serviço do EKS
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  # Cria a role do cluster EKS
  name               = "${local.name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  # Anexa a policy básica do EKS Cluster
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Security Group do Cluster ---
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${local.name}-eks-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id  # Associado à VPC criada previamente
}

# --- EKS Cluster ---
resource "aws_eks_cluster" "this" {
  name     = "${local.name}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn  # Role do cluster
  version  = var.kubernetes_version             # Versão do Kubernetes

  vpc_config {
    subnet_ids              = var.public_subnet_ids        # Subnets públicas para endpoint
    security_group_ids      = [aws_security_group.eks_cluster_sg.id] # SG do cluster
    endpoint_public_access  = true    # Endpoint acessível publicamente
    endpoint_private_access = false   # Endpoint privado desativado
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy  # Garante que role tenha policy
  ]
}

# --- IAM Role do Node Group ---
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]   # Permite que nodes EC2 assumam o role
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]  # Serviço EC2
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  # Role para os worker nodes
  name               = "${local.name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role      = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"  # Permissões básicas do node
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role      = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"  # Permissões de networking (CNI)
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role      = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # Permite puxar imagens do ECR
}

# --- Node Group (em subnets públicas) ---
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.public_subnet_ids  # Nodes em subnets públicas

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"  # Nodes pagos por demanda

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1  # Atualizações graduais sem derrubar todos os nodes
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}

# --- OIDC Provider (para IRSA no futuro: ArgoCD)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer  # Certificado TLS do endpoint OIDC
}

resource "aws_iam_openid_connect_provider" "eks" {
  # Permite pods assumirem roles IAM via Service Account (IRSA)
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}
