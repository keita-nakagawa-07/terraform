#!/usr/bin/env bash
# 既存の Cloud Run function の設定を読み取り、terraform.tfvars の下書きと
# ソース zip を出力する。
#   使い方: ./scripts/export_current.sh PROJECT_ID REGION FUNCTION_NAME
set -euo pipefail

PROJECT="${1:?PROJECT_ID}"
REGION="${2:?REGION}"
FN="${3:?FUNCTION_NAME}"
OUT_DIR="export-${FN}"
mkdir -p "$OUT_DIR"

gcloud functions describe "$FN" --project="$PROJECT" --region="$REGION" \
  --format=json > "$OUT_DIR/function.json"

SA=$(jq -r '.serviceConfig.serviceAccountEmail' "$OUT_DIR/function.json")
SA_ID="${SA%@*}"

if [[ "$SA" == *"-compute@developer.gserviceaccount.com" ]]; then
  echo "警告: デフォルト Compute SA ($SA) で動いています。" >&2
  echo "      import せず、専用 SA を新規作成して付け替えることを推奨します。" >&2
fi

ROLES=$(gcloud projects get-iam-policy "$PROJECT" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:$SA" \
  --format="value(bindings.role)" | sort -u)

# --- terraform.tfvars の下書き ---
{
  echo "project_id    = \"$PROJECT\""
  echo "region        = \"$REGION\""
  echo "function_name = \"$FN\""
  echo
  jq -r '
    "runtime     = \"\(.buildConfig.runtime)\"",
    "entry_point = \"\(.buildConfig.entryPoint)\"",
    "",
    "available_memory                 = \"\(.serviceConfig.availableMemory)\"",
    (if .serviceConfig.availableCpu then "available_cpu                    = \"\(.serviceConfig.availableCpu)\"" else empty end),
    "timeout_seconds                  = \(.serviceConfig.timeoutSeconds)",
    "min_instance_count               = \(.serviceConfig.minInstanceCount // 0)",
    "max_instance_count               = \(.serviceConfig.maxInstanceCount // 100)",
    "max_instance_request_concurrency = \(.serviceConfig.maxInstanceRequestConcurrency // 1)",
    "ingress_settings                 = \"\(.serviceConfig.ingressSettings // "ALLOW_ALL")\"",
    "",
    "environment_variables = {",
    ((.serviceConfig.environmentVariables // {}) | del(.LOG_EXECUTION_ID) | to_entries[] | "  \(.key) = \"\(.value)\""),
    "}",
    "",
    "build_environment_variables = {",
    ((.buildConfig.environmentVariables // {}) | to_entries[] | "  \(.key) = \"\(.value)\""),
    "}",
    "",
    "secret_environment_variables = {",
    ((.serviceConfig.secretEnvironmentVariables // [])[] | "  \(.key) = { secret = \"\(.secret)\", version = \"\(.version)\" }"),
    "}"
  ' "$OUT_DIR/function.json"
  echo
  echo "service_account_id = \"$SA_ID\""
  echo "service_account_project_roles = ["
  for r in $ROLES; do echo "  \"$r\","; done
  echo "]"
  echo
  echo "# 公開設定は下記コマンドで allUsers の有無を確認して設定する"
  echo "allow_unauthenticated = false"
} > "$OUT_DIR/terraform.tfvars"

# --- 公開設定の確認 ---
SVC=$(jq -r '.serviceConfig.service | split("/") | last' "$OUT_DIR/function.json")
gcloud run services get-iam-policy "$SVC" --project="$PROJECT" --region="$REGION" \
  --format=json > "$OUT_DIR/run-iam-policy.json" || true

# --- 個別リソースに付いた SA の権限（参考） ---
gcloud asset search-all-iam-policies --scope="projects/$PROJECT" \
  --query="policy:$SA" \
  --format="table(resource, policy.bindings.role)" > "$OUT_DIR/resource-level-iam.txt" 2>/dev/null || true

# --- ソースコードのダウンロード ---
BUCKET=$(jq -r '.buildConfig.source.storageSource.bucket // empty' "$OUT_DIR/function.json")
OBJECT=$(jq -r '.buildConfig.source.storageSource.object // empty' "$OUT_DIR/function.json")
if [[ -n "$BUCKET" && -n "$OBJECT" ]]; then
  gcloud storage cp "gs://$BUCKET/$OBJECT" "$OUT_DIR/source.zip"
  mkdir -p "$OUT_DIR/src" && unzip -oq "$OUT_DIR/source.zip" -d "$OUT_DIR/src"
else
  echo "ソースの保存場所が取得できませんでした。コンソールの「ソース」タブからダウンロードしてください。" >&2
fi

echo "出力先: $OUT_DIR/"
echo "  terraform.tfvars        → ルートにコピーして確認"
echo "  src/                    → ルートの src/ に置き換え"
echo "  run-iam-policy.json     → allUsers があれば allow_unauthenticated = true"
echo "  resource-level-iam.txt  → バケット/シークレット等の個別権限（必要なら追加で管理）"
