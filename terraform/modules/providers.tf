terraform {
  required_version = ">=1.6.2"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>4.25"
    }
  }
}


provider "aws" {
  region = "us-east-1"
  profile = "default"
}