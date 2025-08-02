output "quest_bucket_name" {
  value = aws_s3_bucket.quest_store.bucket
}

output "subscriber_table_name" {
  value = aws_dynamodb_table.subscriber_table.name
}