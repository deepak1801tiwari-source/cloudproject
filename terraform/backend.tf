terraform {
  backend "s3" {
    bucket         = "cloudops-terraform-state-01"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
