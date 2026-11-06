variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "asia-northeast1"
}

# ---------- 関数 ----------

variable "function_name" {
  description = "Cloud Run function の名前（既存を取り込む場合は既存と同じ名前）"
  type        = string
}

variable "description" {
  type    = string
  default = null
}

variable "runtime" {
  description = "ランタイム（例: python312, nodejs22, go122）"
  type        = string
  default     = "python312"
}

variable "entry_point" {
  description = "エントリポイントの関数名"
  type        = string
  default     = "main"
}

variable "source_dir" {
  description = "関数のソースディレクトリ（Terraform ルートからの相対パス）"
  type        = string
  default     = "src"
}

variable "available_memory" {
  type    = string
  default = "256M"
}

variable "available_cpu" {
  type    = string
  default = null # null ならメモリに応じた既定値
}

variable "timeout_seconds" {
  type    = number
  default = 60
}

variable "min_instance_count" {
  type    = number
  default = 0
}

variable "max_instance_count" {
  type    = number
  default = 3
}

variable "max_instance_request_concurrency" {
  type    = number
  default = 1
}

variable "ingress_settings" {
  description = "ALLOW_ALL / ALLOW_INTERNAL_ONLY / ALLOW_INTERNAL_AND_GCLB"
  type        = string
  default     = "ALLOW_ALL"
}

variable "environment_variables" {
  description = "実行時の環境変数"
  type        = map(string)
  default     = {}
}

variable "build_environment_variables" {
  description = "ビルド時の環境変数"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret Manager から注入する環境変数。key = 環境変数名"
  type = map(object({
    secret  = string # シークレット名
    version = optional(string, "latest")
  }))
  default = {}
}

variable "allow_unauthenticated" {
  description = "true なら allUsers に invoker を付与して公開する"
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "認証付きで呼び出しを許可するメンバー（例: serviceAccount:xxx@...）"
  type        = list(string)
  default     = []
}

# ---------- サービスアカウント ----------

variable "service_account_id" {
  description = "実行 SA の ID（@ より前の部分）。既存 SA を取り込む場合は既存と同じ値"
  type        = string
}

variable "service_account_display_name" {
  type    = string
  default = null
}

variable "service_account_project_roles" {
  description = "実行 SA に付与するプロジェクトレベルのロール"
  type        = list(string)
  default     = []
}

variable "create_build_service_account" {
  description = "ビルド専用 SA を作成して使うか。false ならプロジェクトの既定ビルド SA を使う"
  type        = bool
  default     = true
}
