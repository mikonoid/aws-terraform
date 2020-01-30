terraform {
  backend "s3" {
    bucket = "states"
    key = "states/terraform.tfstate"
    region = "eu-central-1"
  }
}
