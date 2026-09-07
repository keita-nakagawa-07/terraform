terraform {
  backend "gcs" {
    bucket = "default-155223-tfstate"
    prefix = "dev"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}