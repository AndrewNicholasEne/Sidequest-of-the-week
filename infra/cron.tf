resource "aws_cloudwatch_event_rule" "weekly_cron" {
  name                = "sidequest-weekly-cron"
  schedule_expression = "cron(0 8 ? * MON *)"

  tags = {
    Environment = var.env
  }
}

resource "aws_cloudwatch_event_target" "send_weekly_quest" {
  rule      = aws_cloudwatch_event_rule.weekly_cron.name
  target_id = var.lambda_function_name
  arn       = aws_lambda_function.weekly_quest_sender.arn
}
