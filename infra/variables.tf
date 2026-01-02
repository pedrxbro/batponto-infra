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
  type = string
  default = "vpc-01fdfbea057417a12" 
}

variable "public_subnet_id" {
  type    = string
  default = "subnet-0af194780a55572f0"
}

variable "key_pair_name" {
  type = string
  default = "batponto-key"
}

variable "ssh_allowed_cidr" {
  type    = string
  default = "179.246.206.105/32" # Casa da Leticia
}

variable "db_secret_arn" {
  type    = string
  default = "arn:aws:secretsmanager:us-east-1:425515537844:secret:rds!db-20c00104-64fd-4c64-9e03-aa5c02dece56-2IoEbk"
}

variable "db_host" { 
    type = string
    default = "batponto-dev-postgres.c0xgw6qssgsw.us-east-1.rds.amazonaws.com"
}
variable "db_port" { 
    type = number
    default = 5432
}
variable "db_name" { 
    type = string
    default = "batponto"
}

# ECR images
variable "backend_image"  { 
    type = string
    default =  "425515537844.dkr.ecr.us-east-1.amazonaws.com/batponto-dev-backend"
}
variable "frontend_image" { 
    type = string
    default =  "425515537844.dkr.ecr.us-east-1.amazonaws.com/batponto-dev-frontend"
}
variable "flyway_image"   { 
    type = string
    default =  "425515537844.dkr.ecr.us-east-1.amazonaws.com/batponto-dev-flyway"
}
