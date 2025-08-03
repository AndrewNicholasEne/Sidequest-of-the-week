resource "aws_lambda_function" "weekly_quest_sender" {
  environment {
    variables = {
      QUEST_BUCKET = aws_s3_bucket.quest_store.bucket
      SUBSCRIBERS_TABLE = aws_dynamodb_table.subscriber_table.name
      SES_TEMPLATE     = "QuestMail"
      SES_FROM         = "eneandrei@outlook.com"
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