variable "domain_name" {
  type        = string
  default     = "goto.example.com"
  description = "FQDN to use for certificate and DNS"
}

variable "certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate to use for CloudFront. Must be in us-east-1."
}

variable "key_rotation" {
  type        = set(string)
  description = <<-EOT
    Key rotation "schedule", unique tokens for signing keys.
    Recommended to use YYYY-MM-DD names and to keep N and N-1 in the list when
    adding new keys. Order doesn't matter. All N keys will be accepted for
    CloudFront signing, only `current_key` will be used for new signatures.
    Old keys can be removed after `sign_expiration` days.
  EOT
  default     = ["2014-08-26"]
}

variable "current_key" {
  type        = string
  description = "MUST be one of the elements of `key_rotation`, this specifies the current signing key to use."
  default     = "2014-08-26"
}

variable "oidc_endpoint" {
  description = "The OIDC endpoint to use for authentication"
  type        = string
}

variable "oidc_client_id" {
  type        = string
  description = "Client ID for OIDC authentication"
}

variable "oidc_org_id" {
  type        = string
  description = "Organization ID for OIDC authentication"
}

variable "signature_expiration_days" {
  type        = number
  description = "Number of days a session cookie will last"
  default     = 1
}
