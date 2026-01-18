//resource "aws_s3_bucket" "example" {
  //bucket = "mys3backendstate"


  //force_destroy = true
 //}
 //resource "aws_s3_bucket" "example" {
  //bucket = "mys3backendstate"
  # acl argument removed due to deprecation
  //region = "us-east-1"
//}

  
data "aws_s3_bucket" "artifact_bucket" {
  bucket = "abrorjoncodepipelines3bucket"  # Replace with your bucket name
}

#add your state file s3 bucket code here
