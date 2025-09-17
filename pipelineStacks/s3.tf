resource "aws_s3_bucket" "example" {
  bucket = "awspipelinetestabroorbucket"
  

  force_destroy = true
}
terraform {
  backend "s3" {
    bucket = "mys3backendstate"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}
#add your state file s3 bucket code here
