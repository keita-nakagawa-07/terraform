terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # bootstrap-wif.sh で作成したバケット
  backend "gcs" {
    bucket = "default-155223-tfstate"
    prefix = "terraform/state"
  }
}

variable "project_id" {
  type    = string
  default = "default-155223"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

# 認証は google-github-actions/auth が設定する ADC を使うので credentials 指定は不要
provider "google" {
  project = var.project_id
  region  = var.region
}

