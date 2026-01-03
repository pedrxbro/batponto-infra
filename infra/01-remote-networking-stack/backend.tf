terraform {
  backend "s3" {
    bucket  = "batponto-tfstate-dev-425515537844"
    key     = "env/dev/01-networking.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
