locals {
  apis = [
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ]

  build_sa_roles = [
    "roles/logging.logWriter",
    "roles/artifactregistry.writer",
    "roles/storage.objectViewer",
  ]

  invokers = concat(
    var.allow_unauthenticated ? ["allUsers"] : [],
    var.invoker_members,
  )
}

data "google_project" "this" {}

# ---------------------------------------------------------------
# API 有効化
# ---------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------
# 実行サービスアカウントと権限
# ---------------------------------------------------------------
resource "google_service_account" "fn" {
  account_id   = var.service_account_id
  display_name = coalesce(var.service_account_display_name, "${var.function_name} runtime")
}

resource "google_project_iam_member" "fn" {
  for_each = toset(var.service_account_project_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.fn.email}"
}

# シークレットを使う場合、該当シークレットへの読み取り権限を付与
resource "google_secret_manager_secret_iam_member" "fn" {
  for_each  = toset([for s in values(var.secret_environment_variables) : s.secret])
  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.fn.email}"
}

# ---------------------------------------------------------------
# ビルド用サービスアカウント（任意）
# ---------------------------------------------------------------
resource "google_service_account" "build" {
  count        = var.create_build_service_account ? 1 : 0
  account_id   = substr("${var.function_name}-build", 0, 30)
  display_name = "${var.function_name} build"
}

resource "google_project_iam_member" "build" {
  for_each = var.create_build_service_account ? toset(local.build_sa_roles) : toset([])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.build[0].email}"
}

# ---------------------------------------------------------------
# ソースコード: zip → GCS
# ---------------------------------------------------------------
resource "google_storage_bucket" "src" {
  name                        = "${var.project_id}-${var.function_name}-src"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }
}

data "archive_file" "src" {
  type        = "zip"
  source_dir  = "${path.module}/${var.source_dir}"
  output_path = "${path.module}/.build/${var.function_name}.zip"
  excludes    = ["__pycache__", ".venv", "node_modules", ".env"]
}

# ファイル名にハッシュを含めることで、コード変更時に再デプロイされる
resource "google_storage_bucket_object" "src" {
  name   = "${var.function_name}-${data.archive_file.src.output_md5}.zip"
  bucket = google_storage_bucket.src.name
  source = data.archive_file.src.output_path
}

# ---------------------------------------------------------------
# Cloud Run function
# ---------------------------------------------------------------
resource "google_cloudfunctions2_function" "fn" {
  name        = var.function_name
  location    = var.region
  description = var.description

  build_config {
    runtime               = var.runtime
    entry_point           = var.entry_point
    environment_variables = var.build_environment_variables
    service_account       = var.create_build_service_account ? google_service_account.build[0].id : null

    source {
      storage_source {
        bucket = google_storage_bucket.src.name
        object = google_storage_bucket_object.src.name
      }
    }
  }

  service_config {
    service_account_email            = google_service_account.fn.email
    available_memory                 = var.available_memory
    available_cpu                    = var.available_cpu
    timeout_seconds                  = var.timeout_seconds
    min_instance_count               = var.min_instance_count
    max_instance_count               = var.max_instance_count
    max_instance_request_concurrency = var.max_instance_request_concurrency
    ingress_settings                 = var.ingress_settings
    environment_variables            = var.environment_variables

    dynamic "secret_environment_variables" {
      for_each = var.secret_environment_variables
      content {
        key        = secret_environment_variables.key
        project_id = var.project_id
        secret     = secret_environment_variables.value.secret
        version    = secret_environment_variables.value.version
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.build,
    google_secret_manager_secret_iam_member.fn,
  ]
}

# ---------------------------------------------------------------
# 呼び出し権限（関数の実体は Cloud Run サービス）
# ---------------------------------------------------------------
resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = toset(local.invokers)
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.fn.service_config[0].service
  role     = "roles/run.invoker"
  member   = each.value
}
