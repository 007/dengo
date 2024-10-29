locals {
  function_handlers = toset(["auth", "link", "index"])
}

data "aws_iam_policy_document" "lambda_assumerole" {
  statement {
    sid     = "LambdaEdgeAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "edgelambda.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda_api_access" {
  statement {
    sid       = "SigningKeyAccess"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.signing.arn]
  }
  statement {
    sid       = "LogWriteAccess"
    actions   = ["logs:PutLogEvents", "logs:CreateLogStream", "logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid = "S3WriteAccess"
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]
    resources = [
      aws_s3_bucket.origin.arn,
      "${aws_s3_bucket.origin.arn}/*",
    ]
  }
}

resource "aws_iam_role" "lambda_role" {
  name_prefix        = "goto-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assumerole.json
  inline_policy {
    name   = "LambdaEdgePolicy"
    policy = data.aws_iam_policy_document.lambda_api_access.json
  }
}

resource "random_id" "lambda" {
  prefix      = "goto-"
  byte_length = 8
}

resource "aws_lambda_function" "goto" {
  for_each         = local.function_handlers
  filename         = "${path.module}/data/lambda_handler.zip"
  function_name    = "${random_id.lambda.hex}-${each.key}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.${each.key}_handler"
  source_code_hash = filebase64sha256("${path.module}/data/lambda_handler.zip")
  runtime          = "python3.12"
  publish          = true

  environment {
    variables = {
      JWKS_URI                  = local.resolved_oidc_config.jwks_uri
      LINK_BUCKET               = aws_s3_bucket.origin.bucket
      OIDC_CLIENT_ID            = var.oidc_client_id
      SIGNATURE_EXPIRATION_DAYS = var.signature_expiration_days
      SIGNING_KEY_ID            = aws_cloudfront_public_key.signing[var.current_key].id
      SIGNING_KEY_SECRET_PATH   = aws_secretsmanager_secret.signing.arn
    }
  }
  timeout       = 10
  memory_size   = 128
  architectures = ["arm64"]
}

resource "aws_lambda_alias" "goto" {
  for_each         = local.function_handlers
  name             = "cloudfront-${each.key}"
  function_name    = aws_lambda_function.goto[each.key].function_name
  function_version = aws_lambda_function.goto[each.key].version
}

resource "aws_lambda_function_url" "goto" {
  for_each           = local.function_handlers
  function_name      = aws_lambda_function.goto[each.key].function_name
  qualifier          = aws_lambda_alias.goto[each.key].name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "goto" {
  for_each          = local.function_handlers
  name              = "/aws/lambda/${aws_lambda_function.goto[each.key].function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}
