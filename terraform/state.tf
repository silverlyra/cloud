resource "aws_s3_bucket" "state" {
  bucket = "lyra-terraform-state"
  acl    = "private"

  versioning {
    enabled = true
  }
}
