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

## TODO: This probably doesn't need to be in the module. This identity could be reused for multiple CF distributions
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Only the cloudfront user can access s3"
}

## See this blog post: https://aws.amazon.com/blogs/compute/implementing-default-directory-indexes-in-amazon-s3-backed-amazon-cloudfront-origins-using-lambdaedge/
resource "aws_iam_role" "lambda_edge" {
  name               = "${replace(var.domain_name, ".", "-")}-lambda-edge"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}


## The lambda must be provisioned in us-east-1 per the docs:
## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-the-edge.html
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  lambda_name = "${replace(var.domain_name, ".", "-")}-lambda-edge" ## Lambda function names can't have .
}

resource "aws_lambda_function" "lambda_edge" {
  depends_on       = [aws_iam_role_policy_attachment.attach_to_lambda_role, aws_cloudwatch_log_group.lambda]
  function_name    = local.lambda_name
  filename         = "${path.module}/assets/lambda_payload.zip"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "index.handler"
  publish          = true
  runtime          = "nodejs12.x"
  source_code_hash = filebase64sha256("${path.module}/assets/lambda_payload.zip")
  provider         = aws.us_east_1


  tags = {
    Name = "${var.domain_name}-lambda-edge"
    Blog = var.domain_name
  }
}

## Manually Add CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/us-east-1.${local.lambda_name}"
  retention_in_days = 7
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.domain_name}-lambda-edge-logging"
  path        = "/service-role/"
  description = "IAM Policy for ${var.domain_name}-lambda-edge-logging"
  policy      = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_to_lambda_role" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_edge.name
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    lambda_function_association {
      event_type   = "origin-request" # We need to rewrite the URL of the origin request
      lambda_arn   = aws_lambda_function.lambda_edge.qualified_arn
      include_body = false
    }
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
