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

provider "aws" {}

resource "aws_s3_bucket" "quest_store" {
  bucket        = "sidequest-quests"
  force_destroy = true

  tags = {
    Name        = "Sidequest Quest Bucket"
    Environment = var.env 
  }
}

resource "aws_s3_bucket_versioning" "quest_store_versioning" {
  bucket = aws_s3_bucket.quest_store.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "subscriber_table" {
  name           = "sidequest-subscribers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "email"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  tags = {
    Name        = "Sidequest Subscribers"
    Environment = "dev"
  }
}