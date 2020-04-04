variable "domain_name" {
  default     = "blog.mr8ball.net"
  description = "The name of the s3 bucket that will match thet website name"
}

variable "s3_storage_class" {
  default     = "ONEZONE_IA"
  description = "Set the storage class for the bucket. Default is One Zone Infrequent Access"
}

variable "s3_transition_days" {
  default     = 1
  description = "Number of days that pass before transition to the cheaper storage class automatically triggers"
}

variable "s3_transition_flag" {
  default     = true
  description = "Boolean deciding whether or not transition is enabled. Default is true"
}

variable "s3_acl" {
  default     = "private"
  description = "Set the acl for the bucket. Default is private because cloudfront will be accessing the bucket."
}

variable "s3_origin_id" {
  default     = ""
  description = "Override the default origin id which is by default the bucket name"
}

## Cloud Front
variable "cf_price_class" {
  default     = "PriceClass_100"
  description = "Set the price class. Defaults to Price Class 100, the cheapest version optimized only for US and Europe"
}

variable "cf_certificate_arn" {
  description = "ARN for ACM Certificate, must be from US-EAST-1???"
}