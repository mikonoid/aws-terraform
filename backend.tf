terraform {
  backend "s3" {
    bucket = "states-mike-test"
    key = "states/terraform.tfstate"
    region = "eu-central-1"
  }
}
