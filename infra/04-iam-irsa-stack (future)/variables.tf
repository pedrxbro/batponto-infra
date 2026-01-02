variable "aws_region" { 
    type = string
    default = "us-east-1" 
}
variable "project"    { 
    type = string 
    default = "batponto" 
}
variable "environment"{ 
    type = string
    default = "dev" 
}

variable "cluster_oidc_issuer" {
  type    = string
  default = "https://oidc.eks.us-east-1.amazonaws.com/id/A50AC51B831AE6C835606EC2DF8B2BD9"
}

variable "db_secret_arn" {
  type    = string
  default = "arn:aws:secretsmanager:us-east-1:425515537844:secret:rds!db-20c00104-64fd-4c64-9e03-aa5c02dece56-2IoEbk"
}

variable "namespace" { 
    type = string 
    default = "batponto" 
}
variable "service_account_name" { 
    type = string
    default = "batponto-app" 
}
