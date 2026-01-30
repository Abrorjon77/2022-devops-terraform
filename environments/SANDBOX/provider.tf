provider "aws" {
    region = "us-east-1"
    default_tags {
      tags = {
        Name = var.environment
      }
    }
}

terraform {
  backend "s3" {
    bucket = "abrorjoncodepipelines3bucket"
    key    = "dags/myfile"
    region = "us-east-1"
  }
}
