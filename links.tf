locals {
  links = {
    "foo"   = "https://sjfoos.com/"
    "bar"   = "https://www.americanbar.org/"
    "index" = "/index.html"
  }
  link_hrefs    = [for k, v in local.links : "    <tr><td><a href=\"/${k}\">${k}</a></td><td><a href=\"${v}\">${v}</a></td></tr>"]
  index_table   = "  <table>\n${join("\n", local.link_hrefs)}\n  </table>"
  index_content = "<html>\n<head><title>index</title></head>\n<body>\n${local.index_table}\n</body>\n</html>"
}

resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.origin.id

  key          = "index.html"
  content_type = "text/html"
  content      = local.index_content
}

resource "aws_s3_object" "auth_redir" {
  bucket = aws_s3_bucket.origin.id

  key          = "auth_redir"
  content_type = "text/html"
  content = trimspace(templatefile("${path.module}/data/auth_redir.html", {
    endpoint        = var.oidc_endpoint,
    client_id       = var.oidc_client_id,
    organization_id = var.oidc_org_id,
  }))
}

resource "aws_s3_object" "error_html" {
  bucket = aws_s3_bucket.origin.id

  key          = "error.html"
  content_type = "text/html"
  content      = "not sure what to do here"
}
