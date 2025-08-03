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