# S3 bucket for video uploads and processed frames.
# AWS Academy LabRole already has S3 full access.
resource "aws_s3_bucket" "videos" {
  bucket        = "${var.project_name}-videos-${var.aws_account_id}"
  force_destroy = true

  tags = { Name = "${var.project_name}-videos" }
}

resource "aws_s3_bucket_public_access_block" "videos" {
  bucket = aws_s3_bucket.videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
