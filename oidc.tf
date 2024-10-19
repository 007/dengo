data "http" "oidc_config" {
  url = var.oidc_config_endpoint

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to fetch OIDC configuration"
    }
  }
}

locals {
  resolved_oidc_config = jsondecode(data.http.oidc_config.response_body)
}
