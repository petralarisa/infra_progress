terraform {
  backend "s3" {
    bucket = "storage.solution.s3"
    key = "terraform.tfstate"
    region = "us-east-1"
  }
}

