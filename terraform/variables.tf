variable "aws_region" {
  description = "The AWS region to use"
  default     = "us-west-2"
}

variable "az_count" {
  description = "Number of availability zones to cover in the region"
  default     = "3"
}

variable "bless_service_name" {
  description = "The `to` value in the KMS encryption context for BLESS authentication"
  default = "bless"
}

variable "vpc_cidr" {
  description = "IPv4 range to use for VPC"
  default     = "10.1.0.0/16"
}

variable "alb_log_delivery_accounts" {
  description = "AWS account ID's for ALB access logging"

  default = {
    us-west-2 = "797873946194"
  }
}
