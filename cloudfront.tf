locals {
  # from https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
  # tflint-ignore: terraform_naming_convention
  CFCachePolicy_CachingDisabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

  # from https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  # tflint-ignore: terraform_naming_convention
  CFOriginRequestPolicy_AllViewerHost = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

  cf_target_origin_id = "origin-${aws_s3_bucket.origin.id}"
}

resource "aws_cloudfront_response_headers_policy" "no_cache" {
  name    = "GoToNoCache"
  comment = "Disable goto/ response caching in the browser"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "no-cache, no-store, must-revalidate, max-age=0"
    }

    items {
      header   = "Pragma"
      override = true
      value    = "no-cache"
    }

    items {
      header   = "Expires"
      override = true
      value    = "0"
    }
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    domain_name = aws_s3_bucket_website_configuration.origin.website_endpoint
    origin_id   = local.cf_target_origin_id
    custom_header {
      name  = "User-Agent"
      value = random_id.bucket_access_header.hex
    }
  }

  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    connection_attempts = 3
    connection_timeout  = 2
    domain_name         = regex("(?:https://)([^/?#]*)", aws_lambda_function_url.goto["auth"].function_url)[0]
    origin_id           = "auth"
  }

  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    connection_attempts = 3
    connection_timeout  = 2
    domain_name         = regex("(?:https://)([^/?#]*)", aws_lambda_function_url.goto["link"].function_url)[0]
    origin_id           = "link"
  }

  origin {
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    connection_attempts = 3
    connection_timeout  = 2
    domain_name         = regex("(?:https://)([^/?#]*)", aws_lambda_function_url.goto["index"].function_url)[0]
    origin_id           = "index"
  }

  aliases             = [var.domain_name]
  comment             = "${var.domain_name} distribution"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_100" # Use only North America and Europe
  default_root_object = "index.html"

  default_cache_behavior {
    cache_policy_id            = local.CFCachePolicy_CachingDisabled
    response_headers_policy_id = aws_cloudfront_response_headers_policy.no_cache.id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    target_origin_id           = local.cf_target_origin_id
    trusted_key_groups         = [aws_cloudfront_key_group.signing.id]
  }

  custom_error_response {
    error_caching_min_ttl = 0
    error_code            = 403
    response_code         = 200
    response_page_path    = "/_/auth/redir"
  }

  ordered_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.CFCachePolicy_CachingDisabled
    path_pattern           = "/"
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = local.cf_target_origin_id
  }

  ordered_cache_behavior {
    allowed_methods          = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = local.CFCachePolicy_CachingDisabled
    origin_request_policy_id = local.CFOriginRequestPolicy_AllViewerHost
    path_pattern             = "/_/auth/login"
    viewer_protocol_policy   = "redirect-to-https"
    target_origin_id         = "auth"
  }

  ordered_cache_behavior {
    allowed_methods          = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = local.CFCachePolicy_CachingDisabled
    origin_request_policy_id = local.CFOriginRequestPolicy_AllViewerHost
    path_pattern             = "/_/link/create"
    viewer_protocol_policy   = "redirect-to-https"
    target_origin_id         = "link"
    trusted_key_groups       = [aws_cloudfront_key_group.signing.id]
  }

  ordered_cache_behavior {
    allowed_methods          = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = local.CFCachePolicy_CachingDisabled
    origin_request_policy_id = local.CFOriginRequestPolicy_AllViewerHost
    path_pattern             = "/_/link/index"
    viewer_protocol_policy   = "redirect-to-https"
    target_origin_id         = "index"
    trusted_key_groups       = [aws_cloudfront_key_group.signing.id]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}
