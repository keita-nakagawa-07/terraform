terraform {
  required_version = ">= 1.7" # import ブロックの for_each を使うため

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }

  # state を GCS に置く場合（推奨）。バケットは事前に作成しておく。
  # backend "gcs" {
  #   bucket = "YOUR_PROJECT_ID-tfstate"
  #   prefix = "cloudrun-function/my-function"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
