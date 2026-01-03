variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "batponto"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type    = string
  default = "vpc-01fdfbea057417a12"
}

# Nodes em subnets públicas
variable "public_subnet_ids" {
  type = list(string)
  default = [
    "subnet-0af194780a55572f0",
    "subnet-0bc6b4322955dc945"
  ]
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

