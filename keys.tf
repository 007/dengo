resource "tls_private_key" "signing" {
  for_each  = var.key_rotation
  algorithm = "RSA"
}

data "tls_public_key" "signing" {
  for_each        = var.key_rotation
  private_key_pem = tls_private_key.signing[each.key].private_key_pem
}

resource "aws_cloudfront_public_key" "signing" {
  for_each    = var.key_rotation
  comment     = "GoTo CF signing key ${each.key}"
  encoded_key = data.tls_public_key.signing[each.key].public_key_pem
  name_prefix = "goto-"
  lifecycle {
    # prevent weirdness with group membership
    create_before_destroy = true
  }
}

resource "random_id" "signing_group" {
  prefix      = "goto-"
  byte_length = 8
}

resource "aws_cloudfront_key_group" "signing" {
  comment = "GoTo CF signing group"
  items   = [for i in aws_cloudfront_public_key.signing : i.id]
  name    = random_id.signing_group.hex
}

resource "aws_secretsmanager_secret" "signing" {
  name_prefix = "goto-"
}

resource "aws_secretsmanager_secret_version" "signing" {
  secret_id     = aws_secretsmanager_secret.signing.id
  secret_string = tls_private_key.signing[var.current_key].private_key_pem
}
