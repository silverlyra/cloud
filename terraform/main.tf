provider "aws" {
  region = "${var.aws_region}"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_shuffle" "az" {
  input        = ["${data.aws_availability_zones.available.names}"]
  result_count = "${var.az_count}"
}

data "aws_caller_identity" "current" {}
