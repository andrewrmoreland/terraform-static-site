terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
}

#Weird provider configuration for module is due to a CloudFront requirement that referenced certificates are located in us-east-1
provider "aws" {
    alias = "us_east_1"
}