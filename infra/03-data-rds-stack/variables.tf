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

variable "private_subnet_ids" {
  type = list(string)
  default = [
    "subnet-0055f173173d30b12",
    "subnet-0c4ea7c685370e60c"
  ]
}

# Banco
variable "db_name" {
  type    = string
  default = "batponto"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage_gb" {
  type    = number
  default = 20
}
