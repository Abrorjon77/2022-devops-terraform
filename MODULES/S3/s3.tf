locals {
  prefix = "ziyotek-${var.bucket_name}"
}
terraform {
  backend "s3" {
    bucket = "mys3backendstate"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

#resource "aws_s3_bucket" "devops_s3_course_2022_moved_resource" {
 # count = var.create_s3 ? 1 : 0
  #bucket = "${var.environment}-${local.prefix}-${data.aws_region.current.id}-${count.index}"

  versioning {
    enabled = var.versioning
  }
  force_destroy = true
}


