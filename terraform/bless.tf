resource "aws_kms_key" "bless" {
  description = "Protects BLESS SSH certificate authority key"
}

resource "aws_kms_alias" "bless" {
  target_key_id = "${aws_kms_key.bless.key_id}"
  name          = "alias/bless"
}

resource "aws_kms_key" "ssh" {
  description = "Provides KMS-based authentication to BLESS"
}

resource "aws_kms_alias" "ssh" {
  target_key_id = "${aws_kms_key.ssh.key_id}"
  name          = "alias/ssh"
}

data "aws_s3_bucket_object" "bless" {
  bucket = "${aws_s3_bucket.lambda.id}"
  key = "bless.zip"
}

resource "aws_lambda_function" "bless" {
  s3_bucket = "${data.aws_s3_bucket_object.bless.bucket}"
  s3_key = "${data.aws_s3_bucket_object.bless.key}"
  s3_object_version = "${data.aws_s3_bucket_object.bless.version_id}"
  function_name = "bless"
  runtime = "python2.7"
  handler = "bless_lambda.lambda_handler"
  role = "${aws_iam_role.bless.arn}"

  environment {
    variables = {
      bless_options_username_validation = "useradd"
      bless_ca_private_key_file = "ca"
      bless_ca_default_password = "${trimspace(file("${path.module}/../assets/bless.password"))}"
      bless_kms_auth_use_kmsauth = "True"
      bless_kms_auth_kmsauth_key_id = "${aws_kms_key.ssh.id}"
      bless_kms_auth_kmsauth_serviceid = "${var.bless_service_name}"
    }
  }
}

resource "aws_iam_role" "bless" {
  name = "bless"
  description = "Role for the BLESS Lambda function"
  assume_role_policy = "${data.aws_iam_policy_document.bless_assume.json}"
}

data "aws_iam_policy_document" "bless_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "bless_cloudwatch" {
  name   = "bless-cloudwatch"
  role   = "${aws_iam_role.bless.id}"
  policy = "${data.aws_iam_policy_document.bless_cloudwatch.json}"
}

data "aws_iam_policy_document" "bless_cloudwatch" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "bless_kms" {
  name   = "bless-kms"
  role   = "${aws_iam_role.bless.id}"
  policy = "${data.aws_iam_policy_document.bless_kms.json}"
}

data "aws_iam_policy_document" "bless_kms" {
  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["${aws_kms_key.bless.arn}", "${aws_kms_key.ssh.arn}"]
  }

  statement {
    actions   = ["kms:GenerateRandom"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "ssh" {
  name = "ssh"
  description = "Permits SSH access to instances via BLESS"
  assume_role_policy = "${data.aws_iam_policy_document.ssh_assume.json}"
}

data "aws_iam_policy_document" "ssh_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["${data.aws_iam_user.admin.arn}"]
    }
  }
}

resource "aws_iam_role_policy" "ssh_kms_auth" {
  name = "ssh-kms-auth"
  role = "${aws_iam_role.ssh.id}"
  policy = "${data.aws_iam_policy_document.ssh_kms_auth.json}"
}

data "aws_iam_policy_document" "ssh_kms_auth" {
  statement {
    actions   = ["kms:Encrypt"]
    resources = ["${aws_kms_key.ssh.arn}"]

    condition {
      test = "StringEquals"
      variable = "kms:EncryptionContext:to"
      values = ["${var.bless_service_name}"]
    }

    condition {
      test = "StringEquals"
      variable = "kms:EncryptionContext:user_type"
      values = ["user"]
    }

    condition {
      test = "StringEquals"
      variable = "kms:EncryptionContext:from"
      values = ["$${aws:username}"]
    }

    condition {
      test = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "ssh_invoke_bless" {
  name = "ssh-invoke-bless"
  role = "${aws_iam_role.ssh.id}"
  policy = "${data.aws_iam_policy_document.ssh_invoke_bless.json}"
}

data "aws_iam_policy_document" "ssh_invoke_bless" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["${aws_lambda_function.bless.arn}"]
  }
}
