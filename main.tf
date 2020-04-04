## Create s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.domain_name
  acl    = var.s3_acl
  policy = data.aws_iam_policy_document.bucket_policy.json

  lifecycle_rule {
    id      = "Transition to cheaper storage"
    enabled = var.s3_transition_flag

    transition {
      days          = var.s3_transition_days
      storage_class = var.s3_storage_class
    }
  }

  tags = {
    Name = var.domain_name
    Blog = var.domain_name
  }
}

locals {
  s3_origin_id = var.s3_origin_id != "" ? var.s3_origin_id : var.domain_name
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Only the cloudfront user can access s3"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name # Region specifc name prevents redirect issues from CloudFront to S3
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.domain_name}"
  default_root_object = "index.html"

  /* TODO: Need to create generic logging bucket first
  logging_config {
    include_cookies = false
    bucket          = "mylogs.s3.amazonaws.com"
    prefix          = "myprefix"
  }*/

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = var.cf_price_class

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Name = var.domain_name
    Blog = var.domain_name
  }

  viewer_certificate {
    acm_certificate_arn = var.cf_certificate_arn
    ssl_support_method  = "sni-only" # Requried if using acm cert
  }
}
