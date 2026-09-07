variable "azure_storage_account" {
  type        = string
  description = "keitaststest"
}

variable "azure_container" {
  type        = string
  description = "sts"
}

variable "azure_path" {
  type        = string
  default     = ""
  description = "/public"
}

variable "azure_client_id" {
  type        = string
  description = "Azure ADアプリ(フェデレーテッドクレデンシャル用)のクライアントID"
}

variable "azure_tenant_id" {
  type        = string
  description = "1c565538-5a72-4dc2-81e3-610bdc5dab9a"
}

variable "gcs_sink_bucket" {
  type        = string
  description = "default-155223-test-bucket"
}