data "aws_iam_group" "admins" {
  group_name = "admins"
}

data "aws_iam_user" "admin" {
  user_name = "admin"
}
