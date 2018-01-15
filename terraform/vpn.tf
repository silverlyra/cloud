data "aws_ami" "vpn" {
  most_recent = true

  filter {
    name   = "name"
    values = ["vpn-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["${data.aws_caller_identity.current.account_id}"]
}

resource "aws_kms_key" "vpn" {
  description = "Protects VPN pre-shared key"
}

resource "aws_kms_alias" "vpn" {
  target_key_id = "${aws_kms_key.vpn.key_id}"
  name          = "alias/vpn"
}

resource "aws_security_group" "vpn" {
  name        = "vpn"
  description = "Allow access to VPN"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.main.cidr_block}"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["73.241.106.148/32"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.home_cidr}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "vpn" {
  ami = "${data.aws_ami.vpn.id}"
  instance_type = "t2.medium"
  subnet_id = "${aws_subnet.public.*.id[0]}"
  iam_instance_profile = "vpn"
  vpc_security_group_ids = ["${aws_security_group.vpn.id}"]
  source_dest_check = false

  tags {
    Name = "vpn"
  }
}

resource "aws_eip" "vpn" {
  vpc = true
  instance = "${aws_instance.vpn.id}"
}

resource "aws_route53_record" "gateway" {
  zone_id = "${aws_route53_zone.cloud.zone_id}"
  name    = "gateway.lyra.cloud"
  type    = "A"
  ttl     = "300"
  records = ["${aws_eip.vpn.public_ip}"]
}

resource "aws_iam_instance_profile" "vpn" {
  name  = "vpn"
  role = "${aws_iam_role.vpn.name}"
}

resource "aws_iam_role" "vpn" {
  name = "vpn"
  description = "Role for the site-site VPN gateway"
  assume_role_policy = "${data.aws_iam_policy_document.vpn_assume.json}"
}

data "aws_iam_policy_document" "vpn_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpn_kms" {
  name   = "vpn-kms"
  role   = "${aws_iam_role.vpn.id}"
  policy = "${data.aws_iam_policy_document.vpn_kms.json}"
}

data "aws_iam_policy_document" "vpn_kms" {
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["${aws_kms_key.vpn.arn}"]
  }
}
