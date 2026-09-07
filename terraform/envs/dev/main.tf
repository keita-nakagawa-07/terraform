provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "test" {
  name          = "${var.project_id}-test-bucket"
  location      = var.region
  force_destroy = true
}