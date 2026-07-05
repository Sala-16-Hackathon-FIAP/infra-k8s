terraform {
  backend "s3" {
    bucket = "fiapx-terraform-state"
    key    = "k8s/terraform.tfstate"
    region = "us-east-1"
  }
}
