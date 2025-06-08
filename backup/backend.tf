# backend.tf

terraform {
  backend "s3" {
    bucket         = "devops-project2-chatapp-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
