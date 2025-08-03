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