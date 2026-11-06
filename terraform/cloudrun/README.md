# Cloud Run function — Terraform

Cloud Run function、実行サービスアカウント、IAM、ソースコードをまとめて管理する Terraform 一式。
`terraform apply` するとソースが zip にまとめられて GCS にアップロードされ、Cloud Build でビルドされてデプロイされる。

## 構成

```
.
├── versions.tf               # Terraform / provider / backend
├── variables.tf
├── main.tf                   # API, SA, IAM, ソースバケット, 関数, invoker
├── outputs.tf
├── terraform.tfvars.example
├── imports.tf.example        # 既存リソースを取り込むときだけ使う
├── scripts/export_current.sh # 既存関数から tfvars 下書きとソースを書き出す
└── src/                      # 関数のソースコード
```

## A. 既存の関数を取り込む場合

```bash
# 1. 既存の設定とソースを書き出す（gcloud, jq が必要）
./scripts/export_current.sh PROJECT_ID asia-northeast1 my-function

# 2. 書き出した内容を配置する
cp export-my-function/terraform.tfvars .
rm -rf src && cp -r export-my-function/src ./src
#    run-iam-policy.json に allUsers があれば allow_unauthenticated = true にする

# 3. import ブロックを有効化する
cp imports.tf.example imports.tf
#    公開している場合は invoker の import のコメントを外す

# 4. 取り込み
terraform init
terraform plan     # import の件数と差分を確認
terraform apply
rm imports.tf      # 取り込み後は不要
```

plan で関数が `update in-place` になるのは想定どおり。ソースの参照先が、Google 管理のバケットから
このコードで作るバケットに切り替わるためで、apply すると同じコードで再デプロイされる。
それ以外の差分（メモリや環境変数など）が出た場合は、tfvars を既存の値に合わせてから apply すること。

**デフォルト Compute SA で動いている場合**は import しない。`service_account_id` に新しい名前を設定し、
`imports.tf` から SA とロールの import ブロックを消して apply すると、専用 SA が作られ、関数がそちらに付け替わる。

## B. 新規に作る場合

```bash
cp terraform.tfvars.example terraform.tfvars   # 値を編集
terraform init
terraform apply
```

## コードの更新

`src/` を編集して `terraform apply` する。zip のハッシュがファイル名に入っているため、変更があれば再デプロイされる。

## 必要な権限（terraform を実行する主体）

- `roles/cloudfunctions.admin`, `roles/run.admin`
- `roles/iam.serviceAccountAdmin`, `roles/resourcemanager.projectIamAdmin`
- `roles/storage.admin`, `roles/serviceusage.serviceUsageAdmin`
- 実行 SA / ビルド SA に対する `roles/iam.serviceAccountUser`（actAs）

## メモ

- `create_build_service_account = true`（既定）にすると、ビルド専用 SA が作られて使われる。
  新しめのプロジェクトでは既定のビルド SA の権限が足りずにビルドが失敗することがあるため、それを避けられる。
- イベントトリガー（Pub/Sub, GCS など）が必要な場合は、`google_cloudfunctions2_function` に `event_trigger` ブロックを追加する。
- バケットやシークレットなど個別リソースへの権限は `resource-level-iam.txt` を確認して、必要に応じて
  `google_storage_bucket_iam_member` などで追加する（シークレット環境変数で使うシークレットへの権限は自動で付与される）。
- 動作確認: Terraform 1.9 / google provider 8.10 で `terraform validate` 済み。
