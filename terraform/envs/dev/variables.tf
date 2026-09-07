
data "google_storage_transfer_project_service_account" "default" {
  project = var.project_id
}

output "sts_service_account_email" {
  value = data.google_storage_transfer_project_service_account.default.email
}

output "sts_service_account_subject_id" {
  value = data.google_storage_transfer_project_service_account.default.subject_id
}