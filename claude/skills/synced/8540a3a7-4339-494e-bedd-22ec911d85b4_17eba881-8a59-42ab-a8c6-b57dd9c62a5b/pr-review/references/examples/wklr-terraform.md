# Review examples mined from legalscape/wklr-terraform

Source: 11 inline review threads and 58 PR-level comments from 25 merged PRs (humans only; author, bots and bare approvals removed). Each example is: the hunk the reviewer pointed at → what they said → what the author did. `AI-assisted` marks comments posted with an AI assistant footer; they count for substance, hand-written ones also for tone.

| # | category | threads |
|---|---|---|
| 1 | 命名・可読性・コード品質 | 2 |
| 2 | アーキテクチャと設計 | 0 |
| 3 | UI/UX とデザイン実装 | 0 |
| 4 | CI/CD・ビルド・依存関係・環境 | 3 |
| 5 | ドメインロジック・データ整合性・DB | 0 |
| 6 | エラーハンドリング・バリデーション・堅牢性 | 4 |
| 7 | テストとカバレッジ | 0 |
| 8 | 型定義・スキーマ設計 | 0 |
| 9 | セキュリティと認証・認可 | 2 |
| 10 | パフォーマンスと最適化 | 0 |
| 11 | ドキュメント・レビュープロセス・コミュニケーション | 0 |
| 12 | 状態管理と非同期処理 | 0 |
| 13 | タイムゾーン・日付・国際化 | 0 |

## 1. 命名・可読性・コード品質

### PR #1131 · `components/dwh/_common/iam.tf`

```diff
+  for_each = toset(concat(
+    google_bigquery_dataset.modeling_staging[*].dataset_id,
+    google_bigquery_dataset.modeling_warehouse[*].dataset_id,
+    google_bigquery_dataset.modeling_mart_dashboard[*].dataset_id,
+  ))
+
+  project    = var.project
+  dataset_id = each.value
+  role       = "roles/bigquery.dataEditor"
+  member     = "user:<email>"
```
**Reviewer:**
> 将来的にはdata eng.のgroupを作ってそれを指定した方が良さそうですが、現時点ではLGTM
**Author (著者が対応):**
> 承知です。ご指摘のとおりですね。
> データエンジニアが増える or 運用者が僕以外に増える タイミングで対応することにします 🙇

### PR #1092 · `components/dwh/prod/monitoring_alerts.tf`

```diff
       display_name = "labs-analytics_load-watson_document_ctr_daily"
       config_id    = "6a7144ae-0000-2e65-b75f-f403045f8568"
     }
+
+    labs_analytics_watson_snippet_rank_ctr_daily = {
+      display_name = "labs-analytics_load-watson_snippet_rank_ctr_daily"
```
**Reviewer:**
> `display_name` ですが、prod の実物は `labs-analytics_load_watson_snippet_rank_ctr_daily`（`load` の後がアンダースコア）でした。ここではハイフンになっています。
> 
> ```
> GCP 実物: labs-analytics_load_watson_snippet_rank_ctr_daily
> この PR : labs-analytics_load-watson_snippet_rank_ctr_daily
>                              ^
> ```
> 
> `config_id` は `6a9bb96b-0000-29de-8fba-9898fbcb1a7d` で実物と一致しているので、**アラート自体は正しく発火します**し、SV チーム側の除外も効きます。影響は表示のみですが、`display_name` はアラートのタイトルと documentation の「クエリ名」に出るので、Slack 通知に出た名前で BigQuery コンソールを検索してもヒットせず、障害対応時に迷いそうです。
> 
> GCP 側の命名が `load_watson` と `load-watson` で割れていて紛らわ …
**Author (議論あり):**
> 確かに、ありがとうございます🙏！

## 4. CI/CD・ビルド・依存関係・環境

### PR #1174 · `components/wklr-jobs/prod/monitoring_alerts.tf`

```diff
   to = google_monitoring_alert_policy.wklr_jobs_mail_error
   id = "projects/valued-clarity-241606/alertPolicies/16390002757498007870"
 }
+
+resource "google_monitoring_alert_policy" "cv_scraping_scheduler_failed" {
+  for_each = local.cv_scraping_jobs
+
+  display_name = "[prod] ${each.key} Scheduler 実行失敗 (CV)"
```
**Reviewer:**
> cloud run jobsのアラートあればschedulerの失敗通知いらなかったりしません？
**Author (著者が対応):**
> @uzimith 
> すみません ↓ は記憶違いで、 job の実行ステータス監視と scheduler の実行ステータス監視をいれてたので、エラーログに関する通知は削除する、という対応をしたという話でした🙏 
> > 他の job だとそうしてますね！
> 元々 scheduler の失敗通知もつけてたんですが、毎回 scheduler 側も job 側もエラーがでるね、という話で scheduler 側のアラートを削ったという記憶です
> 
> なので現状上記はない & 今回検知したいのは Cloud Run Service 内のアプリケーション状態に関してで job 実行ステータスだけだと検知できない、の …

### PR #1065 · `components/wandh/prod/common.tf`

```diff
     "group:<email>",
   ]
 
+  # publish_courtsgojp Job 設定
+  publish_courtsgojp_job_cpu             = "2000m"
+  publish_courtsgojp_job_memory          = "8Gi"
+  publish_courtsgojp_job_timeout         = "10800s"
+  publish_courtsgojp_deletion_protection = true
```
**Reviewer:**
> [review-guide] 【要確認】本PRを先に apply すると、PR #1083 が prod に作った Job 専用 SA を削除します（apply 順序の調整が必要）
> 
> （本PRのコード起因ではなく、apply の順序についての指摘です。この設定ブロック自体に問題はありません。）
> 
> ヘッドコミット 957b1df 後の最新 Atlantis plan（2026-09-07 15:11 UTC）が、3 環境すべてで destroy を含んでいます。
> 
> | project | plan |
> |---|---|
> | `prod-wandh` | 3 to add, 0 to change, **3 to destroy** |
> | `dev-wandh` | 3 to add, 0 to change, **8 to destroy** |
> | `stage-wandh` | 3 to add, 0 to change, **8 to destroy** |
> 
> prod で destroy されるのは以下です。
> 
> ```
> # module.common.google_service_account.courtsgojp_collect will be destroyed
> # …
**Author (著者が対応):**
> ありがとうございます、こちら #1083 はapply・マージありがとうございました！
> すべて 0 to change, 0 to destroy になり、指摘いただいた既存SA・IAMの削除はなくなったことを確認しました。

### PR #1093 · `components/pam/prod/entitlements.tf`

```diff
+
+  lifecycle {
+    prevent_destroy = true
+  }
+}
+
+import {
+  to = google_privileged_access_manager_entitlement.deploy
+  id = "projects/${local.project}/locations/global/entitlements/deploy"
+}
```
**Reviewer:**
> 単純に気になっただけなのですが、これらのimport文は`terraform apply`後に削除しますか？
**Author (著者が対応):**
> 削除します！

## 6. エラーハンドリング・バリデーション・堅牢性

### PR #1137 · `components/monitor/prod/cloudrun_error.tf`

```diff
         message        = "REGEXP_EXTRACT(jsonPayload.message, \"(.*)\")"
         message2       = "REGEXP_EXTRACT(textPayload, \"(.*)\")"
         message3       = "REGEXP_EXTRACT(protoPayload.status.message, \"(.*)\")"
+        # ls-common-logger 等が構造化フィールド `error` に入れるエラー本文。
+        # message には汎用メッセージしか入らないため、原因を通知に載せるには別途抽出が必要。
+        error = "REGEXP_EXTRACT(jsonPayload.error, \"(.*)\")"
```
**Reviewer:**
> ```suggestion
>         error = "REGEXP_EXTRACT(jsonPayload.metadata.error, \"(.*)\")"
> ```
**Outcome:** 返信なし

### PR #1137 · `components/monitor/prod/cloudrun_error.tf`

```diff
         message        = "REGEXP_EXTRACT(jsonPayload.message, \"(.*)\")"
         message2       = "REGEXP_EXTRACT(textPayload, \"(.*)\")"
         message3       = "REGEXP_EXTRACT(protoPayload.status.message, \"(.*)\")"
+        # ls-common-logger 等が構造化フィールド `error` に入れるエラー本文。
+        # message には汎用メッセージしか入らないため、原因を通知に載せるには別途抽出が必要。
```
**Reviewer:**
> ```suggestion
>         # ls-logger 等が構造化フィールド `metadata.error` に入れるエラー本文。
>         # message には汎用メッセージしか入らないため、原因を通知に載せるにはこの抽出が必要。
> ```
**Outcome:** 返信なし

### PR #1137 · `components/monitor/prod/cloudrun_error.tf`

```diff
         message        = "REGEXP_EXTRACT(jsonPayload.message, \"(.*)\")"
         message2       = "REGEXP_EXTRACT(textPayload, \"(.*)\")"
         message3       = "REGEXP_EXTRACT(protoPayload.status.message, \"(.*)\")"
+        # ls-logger 等が構造化フィールド `metadata.error` に入れるエラー本文。
+        # message には汎用メッセージしか入らないため、原因を通知に載せるにはこの抽出が必要。
+        error = "REGEXP_EXTRACT(jsonPayload.metadata.error, \"(.*)\")"
```
**Reviewer:**
> 近日 ls-logger（legalscape/wklr-mono#7726）が導入されるので、この形で入れていただけるとありがたいです 🙏
> 
> ls-logger の正規フィールドは `data.error` で、`metadata.error` は ls-common-logger 互換のためだけに並行出力しており、移行完了後に削除する予定です。両方抽出しておくと移行前後どちらでも通知に載り、削除時は `error` 側を落とすだけで済みます。
> 
> ```suggestion
>         # ls-common-logger（現行）はメタを metadata.* に、ls-logger（移行先）は data.* に出す。
>         # ls-logger の legacy 互換モードは両方を並行出力するが、metadata.* は移行完了後に削除される。
>         error  = "REGEXP_EXTRACT(jsonPayload.metadata.error, \"(.*)\")"
>         error2 = "REGEXP_EXTRACT(jsonPayload.data.error, \"(.*)\")"
> ```
> 
> `documentation.co …
**Outcome:** 議論あり

### PR #1126 · `modules/service_external_error/main.tf`

```diff
+    # label_pattern の限界: error_kind ラベルは REGEXP_EXTRACT(jsonPayload.message, ...)
+    # で message の部分文字列しか値にできず、本パターンの識別子は stack_trace 側に
+    # あるため、ラベルは "予期しないエラー" という粗い値になる。SV-5281 でコード側が
+    # Azure 5xx を分類し専用メッセージを出せば具体名に置き換えられる（本パターンは
+    # それまでの暫定対応）。
+    # https://linear.app/legalscape/issue/SV-6064
+    {
+      kind          = "AzureServerError"
+      message       = "Holmesで予期しないエラーが発生しました"
+      stack_trace   = "openai\\.APIError: (The server had an error processing your request|An error occurred while processing the request\\.|The system is currently experiencing high demand)"
```
**Reviewer:**
> [review-guide] 【提案】 kind = "AzureServerError" が判定式と対応していません
> 
> 判定式は message と stack_trace の AND ですが、stack_trace 側は openai.APIError の
> 3 メッセージを見ているだけで、Azure であることをどこでも確認していません。生成される
> フィルタにも azure / azure.py という文字列は出てきません。
> 
>     (jsonPayload.message=~"Holmesで予期しないエラーが発生しました"
>      AND jsonPayload.stack_trace=~"openai\.APIError: (The server had an error ...|...)")
> 
> 今は「wandh の経路で openai.APIError が出るのは Azure だけ」という経験則で成立していて、
> 実際 prod の直近18日の一致 91 件は全件 langchain_openai/chat_models/azure.py を含んで
> いました（gcloud logging read の読み取りのみで確認）。ただしコードがそう保証している
> わけではないので、 …
**Outcome:** 返信なし

## 9. セキュリティと認証・認可

### PR #1065 · `components/wandh/_common/publish_courtsgojp_job.tf`

```diff
+
+  lifecycle {
+    ignore_changes = [
+      template.0.template.0.containers.0.image,
+      # 外部 workflow が書き換えるため Terraform では追わない。
+      client,
+      client_version,
+    ]
+  }
+}
```
**Reviewer:**
> [review-guide] 【提案・nit】`depends_on = [module.azure_openai_api_key_japaneast]` が無く、同 component 内の他リソースと不揃いです
> 
> この Job は `module.azure_openai_api_key_japaneast.secret_key` を参照していますが、同 `_common` 内で同じ module を参照している他のリソースはいずれも `depends_on` に挙げています。
> 
> - `api_service.tf:347`
> - `li_service.tf:304`
> - `embedding_service.tf:253`
> - `deep_research_job.tf:278`
> 
> `module.<name>.secret_key` の参照だけでは `modules/secret` 内の `google_secret_manager_secret_iam_member.secret_accessors`（= accessor 付与）への依存が成立しないため、厳密には「secret はあるが IAM がまだ」の順序で Cloud Run 側の検証が走りうる形になります。
> 
> ** …
**Author (著者が対応):**
> ありがとうございます、こちら depends_on に module.azure_openai_api_key_japaneast を追加しました。

### PR #1065 · `components/wandh_es_index_tokyo/mappings/case_courtsgojp-v1.json`

```diff
+        }
+      },
+      "tokenizer": {
+        "ngram_tokenizer": {
+          "type": "ngram",
+          "min_gram": 2,
+          "max_gram": 3,
+          "token_chars": ["letter", "digit"]
+        }
+      },
```
**Reviewer:**
> [review-guide] 【提案・nit】`ngram_tokenizer` / `ngram_analyzer` が未使用です
> 
> `settings.analysis` は `guidelines-v1.json` から丸ごと転記されていますが、`guidelines-v1` が `title.ngram` サブフィールドで使っていた `ngram_analyzer`（33-38 行目）とその `ngram_tokenizer`（11-17 行目、この箇所）を、`case_courtsgojp-v1` の `mappings` はどこからも参照していません。
> 
> 動作上の害はありませんが、「日本語検索用に既存 guidelines-v1 と同じ kuromoji analyzer を設定」という PR 本文の意図に対して余分な定義が残っている状態です。
> 
> 将来 `case_name` 等に ngram サブフィールドを足す予定があるなら残す価値があるので、その場合は「将来利用のため残置」のコメントを添えていただけると読み手に親切です。予定が無ければ削るのが素直だと思います。
> 
> nit なのでこのままマージでも構いません。
**Author (著者が対応):**
> 未使用の ngram_tokenizer / ngram_analyzer を削除し、Terraform側の analysis_tokenizer を省略可能にし、tokenizer定義がない場合もPlanが通るようにしました。

## PR-level review summaries (how approvals and pushbacks are worded)

### PR #1170
> applyしました
> 
> ```
> Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the
> following symbols:
>   + create
> 
> Terraform will perform the following actions:
> 
>   # azurerm_role_assignment.atlantis["atlantis"] will be created
>   + resource "azurerm_role_assignment" "atlantis" {
>       + condition_version                = (known after apply)
>       + id                               = (known after apply)
>       + name                             = (known after apply)
>       + principal_id                     = "7cc96d7e-2342-4139-9c70-00e246add0b8" …

### PR #1160 · APPROVED
> FYI: MHMポータルは許可ログが出ないため、対象APIで429が発生すると集計値が偏る可能性があります。エッジケースなので追加対応は不要です。一旦進めて、実ログとグラフの表示を確認してみてください。

### PR #1159
> この差分は多分あってもなくても同じだろうと解釈しました
> 
> ```
> - rai_policy_name            = "Microsoft.DefaultV2" -> null
> ```

### PR #1135
> applyしました！
> ```
> Terraform will perform the following actions:
> 
>   # google_project_iam_member.atlantis_su_project_iam_admin will be created
>   + resource "google_project_iam_member" "atlantis_su_project_iam_admin" {
>       + etag    = (known after apply)
>       + id      = (known after apply)
>       + member  = "serviceAccount:<email>"
>       + project = "legalscape-zdr-api"
>       + role    = "roles/resourcemanager.projectIamAdmin"
>     }
> 
>   # google_project_iam_member.atlantis_su_service_usage_admin will be created
>   + resource "google_project_iam_mem …

### PR #1126 · COMMENTED
> 見るの遅くなってしまいすみません・・・一点だけ、aiが良さそうなことを言ってきたのでコメントしました（私自身は正規表現弱者ですが・・・・）

### PR #1083 · APPROVED
> LGTM です。純追加で既存挙動が変わらず、他 state への依存も無いので、単独で apply して問題ないと思います。
> metricWriter / logWriter の追加と PR 分割、対応ありがとうございました。
> 
> 1 点だけ PR-B (#1084) でお願いしたいことがあります。
> 
> #1072 にあった設計意図のコメントが、A/B 分割の過程で落ちているようです。意図的な削除ではなく脱落に見えたので（contents 側は残っているため）、PR-B でまとめて戻していただけると助かります。
> 
> - `components/wandh/_common/publish_laws_job.tf` … SA を直接作成する理由 / IAM 付与方針 / bucket objectUser が必要な理由
> - `components/wandh/_common/courtsgojp_collect_job.tf` … SA を直接作成する理由
> - `components/cloud_storage/_common/courtsgojp_collect.tf` … 「別 state で管理するため data source 参照せず決定的な email を使う」
> - `components/wandh_es_project/_common/secrets.tf` … 「別 stat …

### PR #1092 · COMMENTED
> prod の BigQuery Data Transfer の実物と突き合わせました。`config_id` は一致しており、配線（SV チーム側アラートの除外 + Labs 向けポリシーの生成）もマップに 1 件足すだけで両方に反映されるので、構造的な漏れはありませんでした。
> 
> `display_name` の 1 文字だけコメントしています。

### PR #1092 · COMMENTED
> 修正ありがとうございます。prod の BigQuery Data Transfer と再度突き合わせて、4 件すべて `display_name` / `config_id` が実物と一致していることを確認しました。
> 
> ```
> ✅ 6a643703  labs-analytics_load_watson_search_result_group
> ✅ 6a6880da  labs-analytics_load-watson_search_result_event
> ✅ 6a7144ae  labs-analytics_load-watson_document_ctr_daily
> ✅ 6a9bb96b  labs-analytics_load_watson_snippet_rank_ctr_daily   ← 今回追加
> ```
> 
> 差分も該当の 1 行のみで、他への影響はありません。LGTM です。
