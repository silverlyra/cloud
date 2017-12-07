resource "aws_vpc" "main" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  assign_generated_ipv6_cidr_block = true

  tags {
    Name = "lyra"
  }
}

resource "aws_vpc_dhcp_options" "main" {
  domain_name         = "${aws_route53_zone.internal.name} ${var.aws_region}.compute.internal"
  domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.main.id}"
}

resource "aws_subnet" "public" {
  count                   = "${var.az_count}"
  vpc_id                  = "${aws_vpc.main.id}"
  availability_zone       = "${random_shuffle.az.result[count.index]}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)}"
  ipv6_cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.main.ipv6_cidr_block, 4, 0), 4, count.index)}"
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch = true

  tags {
    Name = "public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = "${var.az_count}"
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${random_shuffle.az.result[count.index]}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + 8)}"
  ipv6_cidr_block = "${cidrsubnet(cidrsubnet(aws_vpc.main.ipv6_cidr_block, 4, 1), 4, count.index)}"
  assign_ipv6_address_on_creation = true

  tags {
    Name = "private-${count.index}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "public"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "default" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${element(aws_subnet.public.*.id, 1)}"
  depends_on    = ["aws_internet_gateway.default"]
}

resource "aws_egress_only_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "private"
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.default.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = "${aws_egress_only_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "public" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}
