//resource "aws_s3_bucket" "example" {
  //bucket = "mys3backendstate"


  //force_destroy = true
 //}
 //resource "aws_s3_bucket" "example" {
  //bucket = "mys3backendstate"
  # acl argument removed due to deprecation
  //region = "us-east-1"
//}
data "aws_s3_bucket" "existing" {
  bucket = "mys3backendstate"
}

resource "aws_s3_bucket_object" "tfstate" {
  bucket = data.aws_s3_bucket.existing.id
  key    = "terraform.tfstate"
  //source = "path/to/your/local/terraform.tfstate"
}

  

#add your state file s3 bucket code here
