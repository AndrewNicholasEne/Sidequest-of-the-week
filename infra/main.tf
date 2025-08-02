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

resource "aws_lambda_function" "weekly_quest_sender" {
  function_name = "weekly-quest-sender"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "WeeklyQuestSender::WeeklyQuestSender.Function::FunctionHandler"
  runtime       = "dotnet8"
  timeout       = 30
  memory_size   = 128
  filename = "../handlers/WeeklyQuestSender/src/WeeklyQuestSender/artifacts/WeeklyQuestSender.zip"
  source_code_hash = filebase64sha256("../handlers/WeeklyQuestSender/src/WeeklyQuestSender/artifacts/WeeklyQuestSender.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name = "weekly-quest-sender-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
