# Dengo

Serverless golink / short URL service with auth

## Features

* **Secure** : OIDC authentication required before redirects will work
* **Cheap** : Should fit comfortably in the Free Tier for anything except the heaviest usage
* **Scalable and Resilient** : Lambda compute is only used for initial authentication, then everything is served and authorized directly by CloudFront
* **No servers to manage** : Built on Lambda, CloudFront and S3

## Usage
```terraform
module "go" {
  source = ".../releases/download/v0.0.1/dengo.zip"

  domain_name    = "goto.example.com"
  oidc_endpoint  = "some-host-name.on.auth0.com"
  oidc_client_id = "a0B1c2D3e4F5g6H7i8J9k0L1m2N3o4P5"
  oidc_org_id    = "org_A1b2C3d4E5f6G7h8"
}
```



## Module Details

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->

## Why?

It's named after Goto Dengo from `Cryptonomicon` by Neal Stephenson.

[S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html) with a CloudFront CDN to fake the domain name gives you 99.9% of what you need for a simple link redirect service.  The only missing piece is authentication, and there's no prebuilt service or option to require OIDC authentication for access to a CloudFront distribution.  Even with something like Cognito there's no way to hook it up directly to CloudFront for auth.  The usual way to work around this is to use Lambda or Lambda@Edge to auth _every request_, or to generate signed URLs on-the-fly, but both of those are too expensive and unnecessary for what should be a simple task.

This module works around those drawbacks by using a single Lambda to authenticate the user via OIDC, then generates [signed cookies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-cookies.html) for CloudFront to use for authorization.  This way, the only requests that hit Lambda are the ones that need to be authenticated (default once per day), and everything else is served and authorized directly by CloudFront.

Redirects are handled by [setting the `x-amz-website-redirect-location` header](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html#redirect-requests-object-metadata) on objects in the bucket.  The bucket is [locked down](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-useragent) to only allow access from the [CloudFront distribution](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/add-origin-custom-headers.html), and the distribution requires a [signed cookie to access it](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html).
