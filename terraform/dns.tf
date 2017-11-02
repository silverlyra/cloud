resource "aws_route53_zone" "cloud" {
  name = "lyra.cloud"
}

resource "aws_route53_zone" "internal" {
  name   = "lyra.red"
  vpc_id = "${aws_vpc.main.id}"
}
