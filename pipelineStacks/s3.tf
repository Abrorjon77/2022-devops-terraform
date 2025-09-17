resource "aws_s3_bucket" "example" {
  bucket = "awspipelinetestabroorbucket"
  acl    = "private"

  force_destroy = true
}

#add your state file s3 bucket code here
