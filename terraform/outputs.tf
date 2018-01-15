output "availability_zones" {
  value = "${random_shuffle.az.result}"
}

output "ipv6_subnet" {
  value = "${aws_vpc.main.ipv6_cidr_block}"
}

output "state_bucket" {
  value = "${aws_s3_bucket.state.id}"
}
