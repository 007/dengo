resource "aws_s3_bucket" "origin" {
  bucket_prefix = "goto-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "random_id" "bucket_access_header" {
  prefix      = "access-"
  byte_length = 32
}

data "aws_iam_policy_document" "bucket_limited_access" {
  statement {
    sid       = "CloudFrontLimitedAccess"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.origin.id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:UserAgent"
      values   = [random_id.bucket_access_header.hex]
    }
  }
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "cf_access" {
  bucket = aws_s3_bucket.origin.id
  policy = data.aws_iam_policy_document.bucket_limited_access.json

  depends_on = [aws_s3_bucket_public_access_block.origin]
}
