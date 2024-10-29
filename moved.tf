# auth
moved {
  from = aws_lambda_function.auth
  to   = aws_lambda_function.goto["auth"]
}

moved {
  from = aws_lambda_alias.auth
  to   = aws_lambda_alias.goto["auth"]
}

moved {
  from = aws_lambda_function_url.auth
  to   = aws_lambda_function_url.goto["auth"]
}

moved {
  from = aws_cloudwatch_log_group.auth
  to   = aws_cloudwatch_log_group.goto["auth"]
}

# link
moved {
  from = aws_lambda_function.link
  to   = aws_lambda_function.goto["link"]
}

moved {
  from = aws_lambda_alias.link
  to   = aws_lambda_alias.goto["link"]
}

moved {
  from = aws_lambda_function_url.link
  to   = aws_lambda_function_url.goto["link"]
}

moved {
  from = aws_cloudwatch_log_group.link
  to   = aws_cloudwatch_log_group.goto["link"]
}
