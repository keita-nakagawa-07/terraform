output "function_url" {
  value = google_cloudfunctions2_function.fn.url
}

output "cloud_run_service" {
  value = google_cloudfunctions2_function.fn.service_config[0].service
}

output "runtime_service_account" {
  value = google_service_account.fn.email
}
