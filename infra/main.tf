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
  environment {
    variables = {
      QUEST_BUCKET = aws_s3_bucket.quest_store.bucket
      SUBSCRIBERS_TABLE = aws_dynamodb_table.subscriber_table.name
    }
  }
  
  function_name = var.lambda_function_name
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

resource "aws_cloudwatch_event_rule" "weekly_cron" {
  name                = "sidequest-weekly-cron"
  schedule_expression = "cron(0 8 ? * MON *)"

  tags = {
    Environment = var.env
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.weekly_quest_sender.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_cron.arn
}

resource "aws_cloudwatch_event_target" "send_weekly_quest" {
  rule      = aws_cloudwatch_event_rule.weekly_cron.name
  target_id = var.lambda_function_name
  arn       = aws_lambda_function.weekly_quest_sender.arn
}

resource "aws_iam_policy" "lambda_quest_s3_access" {
  name = "lambda-quest-s3-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::sidequest-quests/quests.json"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_quest_s3_access.arn
}

resource "aws_iam_policy" "lambda_dynamo_access" {
  name = "lambda-dynamo-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:Scan"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.subscriber_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_dynamo_access.arn
}