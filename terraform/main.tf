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

data "aws_ami" "ubuntu_ssd" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
