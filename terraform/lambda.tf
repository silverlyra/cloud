resource "aws_s3_bucket" "lambda" {
  bucket = "lyra-lambda-functions"
  acl    = "private"

  versioning {
    enabled = true
  }
}
