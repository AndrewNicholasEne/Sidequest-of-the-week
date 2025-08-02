terraform {
  backend "s3" {
    bucket         = "sidequest-terraform-state"
    key            = "sidequest/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}