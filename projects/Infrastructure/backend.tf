terraform {
  backend "s3" {
    bucket = "tf-devops-ai-statefile"
    key    = "devops-ai/terraform.tfstate" #replace with your desired path
    region = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
