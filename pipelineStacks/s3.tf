//resource "aws_s3_bucket" "example" {
  //bucket = "mys3backendstate"


  //force_destroy = true
 //}
 resource "aws_s3_bucket" "example" {
  bucket = "mys3backendstate"
  # acl argument removed due to deprecation
  region = "us-east-1"
}


  force_destroy = true

#add your state file s3 bucket code here
