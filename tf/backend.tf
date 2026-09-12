terraform {
  backend "s3" {
    bucket       = "lakehouse-terraform-statefile-bucket"
    key          = "lakehouse/terraform.tfstate"
    region       = "us-west-1" # update to your region
    encrypt      = true
    use_lockfile = true
  }
}
