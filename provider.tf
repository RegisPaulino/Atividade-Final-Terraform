terraform {
  cloud {
    organization = "Mac-01"

    workspaces {
      name = "exer_mack"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "xxxxxxxxxxxxxxxx"
  secret_key = "xxxxxxxxxxxxxxx"
}