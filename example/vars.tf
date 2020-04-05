variable "domain_name" {
  description = "This should be the FQDN of your blog site"
  default     = "fear.is.the.mindkiller"
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM Certificate"
  default     = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-5678-90ab-cdefghijklmn"
}