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

# quais repos criar
variable "repositories" {
  type    = list(string)
  default = ["backend", "frontend", "flyway"]
}

# manter quantas imagens (últimas N)
variable "lifecycle_keep_last" {
  type    = number
  default = 20
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "tag_mutability" {
  type    = string
  default = "MUTABLE" # ou IMMUTABLE
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.tag_mutability)
    error_message = "tag_mutability must be MUTABLE or IMMUTABLE"
  }
}
