provider "aws" {
  region = "us-east-2"
}

module "blog" {
  source             = "../"
  cf_certificate_arn = var.acm_certificate_arn
  domain_name        = var.domain_name
}