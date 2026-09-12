terraform {
  backend "s3" {
    bucket         = "lakehouse-terraform-statefile-bucket"
    key            = "lakehouse/terraform.tfstate"
    region         = "us-west-1" # update to your region
    dynamodb_table = "lakehouse-terraform-state-lock"
    encrypt        = true
  }
}
