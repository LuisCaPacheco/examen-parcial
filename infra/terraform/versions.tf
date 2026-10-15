terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Backend local por defecto. Para equipo: descomentar S3 backend.
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
