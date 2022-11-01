provider "aws" {
    region = "us-east-1"
    default_tags {
      tags = {
        Name = "ziyotek-devops-${var.environment}"
      }
    }
}

terraform {
  backend "s3" {
    bucket = "abror-pipeline-s3-bucket"
    key    = "dags/myfile"
    region = "us-east-1"
  }
}
