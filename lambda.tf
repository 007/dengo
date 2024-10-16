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
      "s3:PutObject",
      "s3:ListBucket"
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

resource "aws_lambda_function" "auth" {
  filename         = "${path.module}/data/lambda_handler.zip"
  function_name    = random_id.lambda.hex
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/data/lambda_handler.zip")
  runtime          = "python3.12"
  publish          = true

  environment {
    variables = {
      OIDC_CLIENT_ID            = var.oidc_client_id
      OIDC_ENDPOINT             = var.oidc_endpoint
      SIGNING_KEY_ID            = aws_cloudfront_public_key.signing[var.current_key].id
      SIGNING_KEY_SECRET_PATH   = aws_secretsmanager_secret.signing.arn
      SIGNATURE_EXPIRATION_DAYS = var.signature_expiration_days
    }
  }
  timeout       = 5
  memory_size   = 128
  architectures = ["arm64"]
}

resource "aws_lambda_alias" "auth" {
  name             = "cloudfront"
  function_name    = aws_lambda_function.auth.function_name
  function_version = aws_lambda_function.auth.version
}

resource "aws_lambda_function_url" "auth" {
  function_name      = aws_lambda_function.auth.function_name
  qualifier          = aws_lambda_alias.auth.name
  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "auth" {
  name              = "/aws/lambda/${aws_lambda_function.auth.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}
