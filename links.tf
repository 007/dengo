locals {
  sample_links = {
    "foo" = "https://sjfoos.com/"
    "bar" = "https://www.americanbar.org/"
  }
  link_hrefs    = [for k, v in local.sample_links : "    <tr><td><a href=\"/${k}\">${k}</a></td><td><a href=\"${v}\">${v}</a></td></tr>"]
  index_table   = "  <table>\n${join("\n", local.link_hrefs)}\n  </table>"
  edit_link     = "<h2><a href=\"/_/link/edit\">Create or edit a link</a></h2>"
  index_content = "<html>\n<head><title>index</title></head>\n<body>\n${local.edit_link}\n${local.index_table}\n</body>\n</html>"
}

resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.origin.id

  key          = "index.html"
  content_type = "text/html"
  content      = local.index_content

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_s3_object" "auth_redir" {
  bucket = aws_s3_bucket.origin.id

  key          = "_/auth/redir"
  content_type = "text/html"
  content = trimspace(templatefile("${path.module}/data/auth_redir.html", {
    auth_endpoint = local.resolved_oidc_config.authorization_endpoint,
    client_id     = var.oidc_client_id,
  }))
}

resource "aws_s3_object" "error_html" {
  bucket = aws_s3_bucket.origin.id

  key          = "error.html"
  content_type = "text/html"
  content      = file("${path.module}/data/link_edit.html")
}

resource "aws_s3_object" "link_edit" {
  bucket = aws_s3_bucket.origin.id

  key          = "_/link/edit"
  content_type = "text/html"
  content      = file("${path.module}/data/link_edit.html")
}
