resource "aws_iam_user" "rainbow" {
  name = "rainbow"
  path = "/system/"
}

resource "aws_iam_access_key" "rainbow" {
  user = "${aws_iam_user.rainbow.name}"
  pgp_key = "keybase:silverlyra"
}

data "aws_iam_policy_document" "rainbow_route53" {
  statement {
    actions   = ["route53:Get*", "route53:List*"]
    resources = ["*"]
  }

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${aws_route53_zone.cloud.zone_id}"]
  }
}

resource "aws_iam_user_policy" "rainbow_route53" {
  name = "route53"
  user = "${aws_iam_user.rainbow.name}"
  policy = "${data.aws_iam_policy_document.rainbow_route53.json}"
}

output "rainbow_access_key_id" {
  value = "${aws_iam_access_key.rainbow.id}"
}

output "rainbow_secret_access_key" {
  value = "${aws_iam_access_key.rainbow.encrypted_secret}"
}
