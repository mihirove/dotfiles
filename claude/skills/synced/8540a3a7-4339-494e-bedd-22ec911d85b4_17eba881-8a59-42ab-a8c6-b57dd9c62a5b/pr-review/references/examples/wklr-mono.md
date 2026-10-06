# Review examples mined from legalscape/wklr-mono

Source: 122 inline review threads and 106 PR-level comments from 73 merged PRs (humans only; author, bots and bare approvals removed). Each example is: the hunk the reviewer pointed at → what they said → what the author did. `AI-assisted` marks comments posted with an AI assistant footer; they count for substance, hand-written ones also for tone.

| # | category | threads |
|---|---|---|
| 1 | 命名・可読性・コード品質 | 6 |
| 2 | アーキテクチャと設計 | 28 |
| 3 | UI/UX とデザイン実装 | 4 |
| 4 | CI/CD・ビルド・依存関係・環境 | 7 |
| 5 | ドメインロジック・データ整合性・DB | 16 |
| 6 | エラーハンドリング・バリデーション・堅牢性 | 29 |
| 7 | テストとカバレッジ | 11 |
| 8 | 型定義・スキーマ設計 | 3 |
| 9 | セキュリティと認証・認可 | 6 |
| 10 | パフォーマンスと最適化 | 0 |
| 11 | ドキュメント・レビュープロセス・コミュニケーション | 8 |
| 12 | 状態管理と非同期処理 | 2 |
| 13 | タイムゾーン・日付・国際化 | 2 |

## 1. 命名・可読性・コード品質

### PR #8520 · `wandh/src/features/shared/watson_reference/references.py`

```diff
     headings: list[str] = []
     context: str | None = None
 
+    # 新ガイドライン検索の GCS artifact を履歴再構築するための内部情報。
+    # API response や通常の model_dump には含めない。
+    processing_version: str | None = Field(default=None, exclude=True)
```
**Reviewer:**
> 法令の LawReferenceMetadata では同じ意味のフィールドが proc_version になっているので、名前を揃えておくのはどうでしょうか。どちらも共通層（watson_reference）のモデルなので、後続の PR で履歴の保存・読み込みを実装するときに名前がばらばらだと、文献種別ごとに読み書きを分けることになりそうです。まだ永続化されていない今のうちに揃えておくのが安く済むと思いました。
**Author (著者が対応):**
> 確かにあまり意味のない法令との差分になってしまっていました🙏 ありがとうございます。法令に揃えて、proc_version にしました：
> - GuidelineReferenceMetadata：processing_version → proc_version
> - feature 内部の GuidelineHit / GuidelineHitData も法令に揃えています。
> - ES の _source から読むキー名も proc_version に修正しました。これは、[こちら](https://github.com/legalscape/wklr-terraform/pull/1172/ …

### PR #8595 · `wandh/src/app/li/answer_transformer.py`

```diff
     mapping: dict[int, SnippetLinkInfo] = {}
     for ref in refs:
         meta = ref.metadata
-        if isinstance(meta, CaseReferenceMetadata):
+        if isinstance(meta, (CaseReferenceMetadata, CaseCourtsgojpReferenceMetadata)):
```
**Reviewer:**
> これは正しいのだろうか？扱われないことになっていないか？
**Author (著者が対応):**
> 意図的に扱わないことにしています🙏
> まだ配線されていないので追加する必要もないといえばないですが、1. 具体的にどう処理するかは後続のPRで書くと思っていますが、CaseCourtsgojpReferenceMetadata の分岐をいれないとCIが落ちるので、どこかに分岐をいれたいです。そこで、勝手に処理が流れるより良いかと思い、ここに分岐を書きました🙏（PR Descriptionにもここを後続で修正して欲しい旨を追記しました）

### PR #8595 · `wandh/src/app/li/reference_transformer.py`

```diff
 
     for ref in refs:
         meta = ref.metadata
-        if isinstance(meta, CaseReferenceMetadata):
+        if isinstance(meta, (CaseReferenceMetadata, CaseCourtsgojpReferenceMetadata)):
```
**Reviewer:**
> ここも同じ、これだと判例絶対使われないのでは
**Author (議論あり):**
> こちらと同じです🙏 → https://github.com/legalscape/wklr-mono/pull/8595#discussion_r4013571695

### PR #8595 · `wandh/src/features/case_courtsgojp_retriever/services/retriever.py`

```diff
+    from src.features.case_courtsgojp_retriever.entities import (
+        CaseCourtsgojpFilter,
+        CaseCourtsgojpQuery,
+    )
+
+
+DEFAULT_RETRIEVAL_TOP_K = 20
+"""1サブクエリあたりESから取得する件数。"""
+
+DEFAULT_MAX_TOP_K = 60
```
**Reviewer:**
> 60って多くないですか？D1もこんなにやってましたっけ？
**Author (著者が対応):**
> すみません設定ファイルの方だけ変更してDEFAULT_MAX_TOP_K = 60の方を修正していませんでした🙏
> こちら `DEFAULT_MAX_TOP_K = 10` に修正しました

## 2. アーキテクチャと設計

### PR #8883 · `packages/ccc-admin-ui/src/routes/articles/-components/article-form.tsx`

```diff
   return <span className="rounded-full bg-red-50 px-2 py-0.5 text-[0.6875rem] font-semibold text-red-700">必須</span>;
 }
 
+function FileInput({
```
**Reviewer:**
> [Should] article特有の仕様ではなさそうなのとファイル添付は多用しそうなので、これは共通コンポーネントとして切り出した方がよさそうです
**Author (著者が対応):**
> 共通コンポーネント \`components/ui/file-input.tsx\` の \`FileInput\` に切り出し、記事フォームはそれを使うようにしました（f022577c3a）。
> 
> - \`DatePicker\` と同じく \`id\`・\`value\`・\`onChange\`・\`onBlur\` と \`aria-invalid\` / \`aria-describedby\` を受け取る形にし、エラー ID の組み立てはフォーム側に残しています
> - 外すボタンは \`clearLabel\` を渡したときだけ出ます
> - 振る舞いと見た目は変えていません（記事登録画面 …

### PR #8650 · `packages/contents-app/src/cli/check_revisions/editionBuilders.ts`

```diff
   const { edition, wklrSharedArticle, wklrSharedDoc } = args;
   // 掲載処理 (publish_revision/article.ts) は edition 固有の期間・利用制限・ページ方向を
   // article テーブルではなく doc に書くため、期待値はこれらを doc から取る。
+  // isExistThumbnail は突合対象外。parse を通すためのダミー値を置く。
```
**Reviewer:**
> thumbnailUriとの突合はしなくて良いんでしたっけ？
**Author (著者が対応):**
> thumbnailUriとhasThumbnailを比較するようにしました
> 
> https://github.com/legalscape/wklr-mono/pull/8650/changes/4006e46c40c808aad156005a72c6995036e26879
> 
> こういうことであってますかね？

### PR #8650 · `packages/contents-app/src/api/routes/documents.$id.editions.ts`

```diff
   attachmentFiles: z.array(z.string()),
 });
 
+// 掲載先 (static.legalscape.jp) が PNG 固定で、掲載ジョブ側に変換器が無いため入稿も PNG に限る。
```
**Reviewer:**
> これまでのサムネイル入稿でもpng固定だったんですかね？
**Author (議論あり):**
> pdfからしか生成しないのでpngしかないはず

### PR #8687 · `packages/contents-core/src/services/revisionService.ts`

```diff
   ): Promise<Edition> {
     const violation = publicationPeriodViolation(edition);
     if (violation) throw new CreateEditionError('publication_period_time_not_fixed', { cause: violation });
+    if (edition.type === 'article') {
```
**Reviewer:**
> [ask] publication_period_invalid_rangeってarticleのみに絞る必要がありますか？
**Author (著者が対応):**
> bookは既存レコードで違反しているので入れられないのですが、別件で対応するのでこのPRからはレンジの検証を丸ごと削除しました。

## 3. UI/UX とデザイン実装

### PR #8650 · `packages/ccc-ui/src/routes/articles/DetailPage.tsx`

```diff
       <Field label="印刷・ダウンロード">{edition.isPrintAndDownloadDisallowed ? '許可しない' : '許可する'}</Field>
       <Field label="内容のコピー">{edition.isContentsCopyDisallowed ? '許可しない' : '許可する'}</Field>
     </Stack>
+    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={6}>
+      <Field label="転載元URL">{edition.sourceUrl ?? '未設定'}</Field>
+      <Field label="サムネイル画像">{edition.isExistThumbnail ? 'あり' : 'なし'}</Field>
+    </Stack>
```
**Reviewer:**
> ここでthumbnailを表示しなくて良いんですかね？
**Author (著者が対応):**
> しなくていいかなと思っていたのですがするように変更しました
> 
> https://github.com/legalscape/wklr-mono/pull/8650/changes#diff-6a734b31acf5b42340dad4e1302b14604ee7881f741ac0933c8c91cb5d604f26R94-R99

### PR #8687 · `packages/ccc-admin-ui/src/routes/articles/-components/breadcrumb.tsx`

```diff
+  BreadcrumbItem,
+  BreadcrumbLink,
+  BreadcrumbList,
+  BreadcrumbPage,
+  BreadcrumbSeparator,
+} from '@/components/ui/breadcrumb';
+
+export function ArticlesBreadcrumb({ current }: { current?: string }) {
+  return (
+    <Breadcrumb aria-label="現在地">
```
**Reviewer:**
> 全く分からないが
> ```suggestion
>     <Breadcrumb aria-label="パンくずリスト">
> ```
> の方が良かったりしないかな
**Author (議論あり):**
> ここはこのままでいいと思っています。（"パンくずリスト" よりは現在地の方が意味がある）

### PR #8750 · `packages/iris/src/features/wandh/components/holmes/Form.tsx`

```diff
-        })
-        .flat();
-      const parentId = answers[answers.length - 1]?.questionId;
+      // 海外法リサーチは 1 履歴 = 1 質問（allibee に会話コンテキストを渡すパラメータが無い。
+      // design-docs/wandh-overseas-research.md の決定事項 5）。更問にはできないので、
+      // 海外法の回答から送信したときは**新しい質問**として投げる。
+      // 文脈を引き継ぐと、国内の ask() に空の assistant テキストと解決できない parentId を
+      // 渡すことになり、前問と無関係な回答が返る。
+      const isExternalHistory = answers[answers.length - 1]?.source === 'external';
+      const res = await labs.preparePostLabsWandhQuestion(inputQuery, isExternalHistory ? undefined : params.id);
```
**Reviewer:**
> L246–266 で海外法の回答からの送信を「履歴・文脈を引き継がない新規質問」にしていますが、L246 は国内用 preparePostLabsWandhQuestion、L312 は国内用 ask を同じ AnswerProvider 上で呼んでおり、新しい res.historyId への画面遷移がありません。そのため海外法の回答の下で「さらに質問」すると、国内の独立した質問が前の回答に続けて表示される一方、URL は海外法の履歴のままです。リロードすると今表示した国内の回答を復元できず、次の更問でも params.id は元の海外法履歴を指します。新規の国内質問として扱うならそのことを UI に明示して res.historyId の画面へ遷移するか、海外法画面からの更問フォームは出さない形にお願いします。
**Outcome:** 返信なし

### PR #8876 · `packages/wklr-admin/src/resources/zdrPolicyChange/show.tsx` · AI-assisted

```diff
           render={(policy?: { id: number; description: string | null }) =>
             `${policy?.id}: ${policy?.description ?? '説明なし'}`
           }
         />
       </ReferenceField>
-      <BooleanField source="requestedRequiresZdr" label="変更後はZDR必須" />
+      <ReferenceField source="liClientPolicyId" reference="liClientPolicies" link={false} label="現在の設定">
+        <ZdrSettingField source="requiresZdr" label="現在の設定" />
+      </ReferenceField>
+      <ZdrSettingField source="requestedRequiresZdr" label="承認後の設定" />
```
**Reviewer:**
> 【AIからの提案・任意】処理済みの申請で「現在の設定」と「承認後の設定」を読み違えやすいかもしれません
> 
> 「現在の設定」は画面を開いた時点のDB値なので、申請中（`pending`）なら意図どおり読めますが、処理済みの申請を後から開くと次のように見えると思います。
> 
> - 却下済み（`rejected`）: 「現在: 通常／承認後: ZDR必須」が並び、却下された申請なのに「承認後」の値が表示される
> - 適用済み（`applied`）の後に別の申請で元に戻された場合: 「現在: 通常／承認後: ZDR必須」が並び、この申請が未適用に見える
> 
> 仕様書には「前者は申請時の旧値ではない」と書かれていますが、画面上には説明がないので、例えば次のような対応はいかがでしょうか。
> 
> - 「現在の設定」は `status === 'pending'` のときだけ表示する
> - 処理済みの申請ではラベルを「申請した設定」にする
> - 「現在の設定（参照時点のDB値）」のように補足を付ける
> 
> 必須ではないので、別PRや見送りでも問題ありません。
**Author (著者が対応):**
> うーん確かにそうですね...あとで直します！

## 4. CI/CD・ビルド・依存関係・環境

### PR #8650 · `packages/wklr-jobs/src/job/publish_revision/article.ts`

```diff
 }
 
+/**
+ * サムネイル画像を static-files へ配るかどうか。
+ *
+ * PDF 掲載は PDF の表紙から生成できるので常に配り、Web 掲載は入稿画像があるときだけ配る。
+ * DB に書く URI もこの述語で決めることで、URI と実ファイルの有無を食い違わせない。
+ */
+function shouldDeployThumbnail(revision: ArticleRevision): boolean {
+  return revision.isPdfViewAvailable || revision.isExistThumbnail;
```
**Reviewer:**
> この辺り暗黙的すぎるのでPDF掲載も含めて hasThumbnail=true に統一すべきだと思っており、チケット追加お願いしたいです
**Author (著者が説明（現状維持 / 別途対応）):**
> わかりました　自分がやります
> 着手なんですが、lw3.0 = v1が出来たあとにそれに対して実装したほうがよさそうな気がしているんですが、lw3.0を待つ必要はありませんか？

### PR #8650 · `packages/wklr-jobs/src/model/deploy_thumbnail/index.ts`

```diff
 import config from 'config';
 
+/**
+ * サムネイルの元になる画像を contents-api の入稿済みファイルから取る場合の指定。
+ *
+ * 省略すると掲載済み PDF の表紙から作る。
+ */
+export type ThumbnailImageSource = {
+  documentId: DocumentId;
+  editionVersion: EditionVersion;
```
**Reviewer:**
> EditionIdではダメなんでしたっけ？一応documentId + version という指定方法はinternalだけに留めたく（最終的に）＿。
**Author (議論あり):**
> > 一応documentId + version という指定方法はinternalだけに留めたく
> 
> ここがピンときてなくて、wklr-jobs の ContentsApiClient は、fetchEditionFile / fetchAttachment / fetchSEC など、どれも documentId + version で contents-api を呼んでいます。contents-api 側にも EditionId で edition を引くルートがまだないので、今回はそれに揃えています
> 
> https://github.com/legalscape/wklr-mono/blob …

### PR #8776 · `.github/workflows/_reusable-ci-package.yml`

```diff
         if: ${{ !cancelled() && steps.setup.outcome == 'success' }}
         run: pnpm --filter ${{ inputs.package }} run check:type
 
+      # structure-core の test:ci は、PDF を PNG にする結合テスト (tests/google/gcv.test.ts) で
+      # poppler-utils の pdftoppm / pdfinfo を実行する。CI では poppler が無いとテストが失敗するので、先に入れる。
+      - name: poppler-utils をインストールする (structure-core)
+        if: ${{ !cancelled() && steps.setup.outcome == 'success' && inputs.package == 'structure-core' }}
+        run: sudo apt-get update && sudo apt-get install -y --no-install-recommends poppler-utils
```
**Reviewer:**
> prepare:ci コマンドが実行されるので、ここに入れるのはどうでしょう？
> 
> https://github.com/legalscape/wklr-mono/blob/376c307da8d966c422764b2789be6f36d9172aad/.github/actions/setup-pnpm-monorepo/action.yml#L131-L134
**Author (著者が対応):**
> そちらの方がよさそうです。prepare:ciで入れるように修正しました。: [変更](https://github.com/legalscape/wklr-mono/pull/8776/changes/1bc8ff654d11b442072c30d17ab65842790ae234)

### PR #8661 · `packages/wklr-jobs/src/model/account_organization/index.ts`

```diff
     console.info(`Syncing users for organization: ${organization.id}`, { context });
 
     const users = await this.repos.transactionForOrganization(organization, async (repos) => {
-      return await repos.user.findAllValid();
+      // 期限切れも同期し、組織DBで停止したユーザーをaccount_platformへ反映する。
+      return await repos.user.findAllNotDeleted();
```
**Reviewer:**
> この変更の影響範囲が kommentar_trial に閉じていないのが気になっています。
> 
> `syncForAllOrganizations` は `this.repos.organization.getAll()`（`repository/organization.ts:17`、`this.repository.find()` でフィルタなし）で**全組織**を回し、各組織に対してこの `syncUsers` を呼びます。組織や oid を見て分岐する箇所はないので、`findAllValid()` → `findAllNotDeleted()` の変更は **全組織の全未削除ユーザー**に効きます。
> 
> 具体的に増えるのは次の 3 つだと理解しています。
> 
> 1. **新規 INSERT が走る。** `createOrUpdateRecord`（`repository/account_organization.ts:45-58`）は既存行が 0 件なら INSERT します。これまで `account_organization` 行を持たなかった期限切れユーザーに、全組織分の行が新しく作られます
> 2. **既存行の `valid_until` が一斉に上書きされる。** 同メソッ …
**Author (著者が対応):**
> まあただ影響範囲大きいというのはそのとおりなので、やばくないか事前調査必要だな。そういう意味ではスコープ縮めるためにいったんこれでいいか。

## 5. ドメインロジック・データ整合性・DB

### PR #8520 · `wandh/src/features/guideline_retriever/entities.py`

```diff
+
+from pydantic import Field
+
+from src.features.shared.base_model import BaseModel
+
+GuidelineType = Literal["guideline", "tsutatsu", "guideline_qa", "tsutatsu_qa"]
+"""検索結果で利用する正規化済みガイドライン種別。"""
+
+
+class GuidelineHit(BaseModel):
```
**Reviewer:**
> 提案です（必須ではないです）。entity が満たすべき値のルールが services 側に散っているので、entity に寄せるとまとまりそうだと思いました。
> 
> 1. id の形式 {revision_id}.{chunk_index}
>    retriever.py で、_parse_chunk_identifier が分解し、_build_hit_clusters が f"{first_hit.revision_id}.{chunk_index}" と手で組み立てていて、形式の知識が 2 か所にあります。GuidelineHit に組み立て／分解のクラスメソッドを置くか、id を revision_id と chunk_index から導くプロパティにすると、ずれようがなくなりそうです。
> 2. 種別の正規化（kokuji → tsutatsu）
>    retriever と fetcher がそれぞれ normalize_guideline_type を呼んでいるので、GuidelineHit / GuidelineHitData の type に field_validator(mode="before") として付ければ呼び忘れがなくなり、helpers.py も不要になり …
**Author (著者が対応):**
> ありがとうございます！3点とも、提案いただいた通り entity に寄せました：
> 1. ID の形式：GuidelineHit にクラスメソッドを追加し、retriever の組み立て・分解を置き換えました。
> 2. 種別の正規化：type に field_validator(mode="before") を付け、helpers.py を削除しました。
> 3. 日付の正規化：published_on / collected_at にfield_validatorを付け、fetcher の _normalize_timestamp を削除しました。
> 
> ES の hit や GCS の chunk J …

### PR #7955 · `packages/wklr-migration/organization/V062__labs_wandh_question.sql`

```diff
+  `deep_research_modify_hints` JSON DEFAULT NULL COMMENT '修正ヒント (list[ResearchModifyHint])',
+  `answer_to_question` MEDIUMTEXT COLLATE utf8mb4_0900_bin DEFAULT NULL COMMENT '元の質問への直接回答',
+
+  -- 評価 (wklr-backend-api の saveWandhEvaluation が書き込む。wandh 外からの追記)
+  `evaluation` JSON DEFAULT NULL COMMENT 'ユーザ評価 (別サービス wklr-backend-api が書き込み)',
+  `evaluated_at` DATETIME(3) DEFAULT NULL COMMENT '評価日時',
+
+  PRIMARY KEY (`id`),
+  KEY `idx_labs_wandh_question_history_id` (`history_id`),
+  KEY `idx_labs_wandh_question_user_asked` (`user_id`, `asked_at`),
```
**Reviewer:**
> wklr-jobs-cli用にasked_atだけのindexもあった方が良さそう？
**Author (議論あり):**
> Datastore って自動indexなのか・・・Good raiseでした

### PR #8650 · `packages/wklr-jobs/src/model/deploy_thumbnail/index.ts`

```diff
     const pathWithoutExt = path.join(workingDir, filenameWithoutExt);
     const exec = util.promisify(child_process.exec);
     await exec(`pdftoppm "${pathWithoutExt}.pdf" -png -f 1 -singlefile -scale-to 400 -cropbox "${pathWithoutExt}"`);
-    await exec(`optipng "${pathWithoutExt}.png"`);
+  }
+
+  /**
+   * PNG を可逆圧縮する。PDF 由来と入稿画像のどちらも同じ圧縮をかけてから配る。
```
**Reviewer:**
> nits: こことは関係ないですが、cccとか入稿に近い場所で「データは1MB以上はNG」とか「1MBを超えたら自動で不可逆圧縮 or リサイズされる」とかしてデータ数に制限かけた方が良さそうな気がしました
**Author (著者が説明（現状維持 / 別途対応）):**
> いいと思います
> 必要だと思うので簡単なチケット作りました　要件整理はまた別途したいと思っています
> 
> https://linear.app/legalscape/issue/CV-2948/入稿されるデータのバリデーションやコンバートについて考える

### PR #8703 · `datamodel/.sqlfluff`

```diff
+    structure.column_order,
+    # GROUP BY ALL を使うため
+    ambiguous.column_references
+large_file_skip_byte_limit = 0
+
+[sqlfluff:templater:dbt]
+project_dir = .
+profiles_dir = .
+profile = wklr_datamodel
+target = dev
```
**Reviewer:**
> dbt使ったことないので調べながらで恐縮ですが、 `target = dev` を指定するとlocal lint時にもdev環境にSQLが発行されるそうなのですが、これは意図的ですか？
**Author (著者が対応):**
> sandboxがいいんじゃない？という指摘ということでしたので修正しました！
> 
> d2166fb2cc2cb9d579ab3a2b5f4c3ca47dc28640

## 6. エラーハンドリング・バリデーション・堅牢性

### PR #8520 · `wandh/src/features/guideline_retriever/services/retriever.py`

```diff
+
+def _build_valid_hits(
+    items: list[dict[str, Any]], *, index_name: str
+) -> list[GuidelineHit]:
+    """不正な ES hit だけを除外し、正常な hit を変換する。"""
+    hits: list[GuidelineHit] = []
+    for item in items:
+        try:
+            hits.append(_build_hit(item))
+        except ValueError as exc:
```
**Reviewer:**
> 確認させてください。_build_valid_hits は ValueError だけを捕まえているので、壊れた hit の扱いが次のように分かれていると読みました。
> 
> - _id の形式が不正・_id と revision_id の不一致・type が null や不明な値 → その hit だけ除外して続行
> - _id / _source / revision_id / type のキー自体が無い → KeyError で質問全体がエラー
> 
> どちらも「index に壊れた document がある」という同じ種類の異常なので、片方は静かに 1 件抜け、もう片方は質問全体が落ちる、という差をつけている意図があれば教えてください。
> 既存だと、法令は try なしで全部 fail-fast、判例は KeyError / TypeError / ValueError をまとめて除外したうえで除外件数を error ログに出しています。揃えるならどちらかに寄せるのがよいと思っています。除外に寄せる場合は、warning だけだと大量に壊れていても気づけないので、判例と同じく除外件数を error で出しておくと安心です。
**Author (著者が対応):**
> ありがとうございます。変に分けてしまていましたが、意図した差ではないです🙏
> 判例の方に揃える方向で修正しました：
> - KeyError / TypeError / ValueError をキャッチして、hit を除外
> - 除外件数を error ログに出力（requested / succeeded / dropped）

### PR #8520 · `wandh/src/features/guideline_retriever/services/retriever.py`

```diff
+    ) -> None:
+        """Retriever を初期化する。"""
+        if max_n_gaps < 0:
+            msg = "max_n_gaps must be greater than or equal to 0"
+            raise ValueError(msg)
+        self._config = config
+        self._max_n_gaps = max_n_gaps
+
+    @instrument_feature_run("guideline_retriever", "retrieve")
+    async def run(
```
**Reviewer:**
> （この PR の範囲外なので、別 PR で検討いただければという提案です）
> fetcher は GCS の取得・解析・schema 検証の失敗を GuidelineHitDataFetchError に包んで外に出していて、呼び出し側は中で GCS を使っていることを知らなくても扱える形になっていてよいと思いました。
> retriever も同じ形に揃えるとよさそうです。今は ES の例外が TaskGroup の ExceptionGroup に入ったまま外に出るので、呼び出し側は「中で ES と TaskGroup を使っている」ことを知らないと扱えません。fetcher と同じく GuidelineRetrieverError のような専用の例外で包んでおくと、技術的な詳細が feature の外に出なくなります。あわせて node 側も Exception ではなく feature の例外を捕まえる形にできそうです。
> なお、法令も「fetcher は失敗を LawHitDataFetchError に包み、retriever は ES の例外をそのまま外に出す」という、ガイドラインと同じ分かれ方になっています。別 PR で対応するなら、法令の retriever にも専用の例外 …
**Author (著者が対応):**
> 確かに、指摘していただいたとおりだと思うので、法令の方と一緒に別 PR で対応しようと思います！
> Issueを作成しました：https://linear.app/legalscape/issue/LAB-1032

### PR #8687 · `packages/ccc-admin-ui/src/components/error-page.tsx`

```diff
 import { APIError } from '@/api/errors';
 import { useDocumentTitle } from '@/hooks/use-document-title';
 
-function errorContent(error: unknown): { title: string; message: string } {
+function errorContent(error: unknown): { title: string; message: string; canRetry: boolean } {
+  if (error instanceof APIError && error.kind === 'unknown-mutation-result') {
+    return {
+      title: '登録結果を確認できませんでした',
+      message: '重複登録を避けるため再登録せず、開発者に登録結果の確認を依頼してください。',
+      canRetry: false,
```
**Reviewer:**
> [nits]
> isRetrySafe みたいに retry 可能かの根拠をあらわす property にしたほうが混乱が少なそうと思いました🙏
**Author (著者が対応):**
> > 後半だけちょっと感覚がちがいまして、ぼくの感覚だと canRetry は操作が安全かどうか以外の理由でも決まると思ってます
> > たとえば 404 が返ってきたとして再度送っても無駄だから retry できないようにしちゃうとかパフォーマンス観点で retry させたくないとかっていうのもあると思っています。
> 
> ちなみに↑この例はどちらもcanRetry=true (i.e. isRetrySafe=true) だとは思っています。（フロントがretryを実行しても良い）

### PR #8750 · `packages/iris/src/features/wandh/components/holmes/Form.tsx`

```diff
-          type="button"
-          onClick={handleClickReset}
-          className={clsx(typography.bodySmRegular, typography.bodyMdRegularSp, styles.resetButton)}
-        >
-          <Icon name="filterReset" pc="md" sp="lg" className={styles.icon} />
-          リセット
-        </button>
+      <div className={styles.bottomContainer} data-visible={isBottomContainerVisible && !isExternalHistory}>
+        {/* 隠すだけだとフォーカスが当たるので、海外法のときは中身も描画しない */}
+        {!isExternalHistory && (
```
**Reviewer:**
> 海外法の履歴を直接開いた場合、この条件分岐で送信ボタンが無効のままになりそうです。
> 
> L86–87 の `isDocumentTypeValid` / `isPublishedOnOrAfterValid` は初期値が `false` ですが、L537–548 で海外法の場合は `DoctypeOption` / `DateOption` を描画しないため、L543・L547 のコールバックによる更新が起きません。一方、L168 の `isWandhFilterValid` → L449 の `isWandhAskable` → L453 の `isSendDisabled` では両方が `true` になることを要求しています。Enter で送信しても L252 で return するため、L260 以降の同じ連携先への新規質問に到達できません。
> 
> 海外法では国内向けフィルターの検証を送信条件から外し、海外法履歴を開いた状態から質問を入力して `/labs/wandh/q/new` へ遷移できるテストを追加するのがよさそうです。
**Author (著者が対応):**
> @aximov 
> コード上問題があったようなので直しました :pray:

## 7. テストとカバレッジ

### PR #8650 · `packages/wklr-jobs/tests/job/publish_revision/article.test.ts`

```diff
     expect(doc.pageDirection).toBe(PageDirection.RL);
   });
 
+  // static-files に画像が載るのは本番だけなので、非本番で URI を入れると壊れたリンクになる
+  test('非本番では入稿画像があっても thumbnailUri は null にする', async () => {
```
**Reviewer:**
> これってアプリ側で担保しているんですかね？
**Author (議論あり):**
> https://github.com/legalscape/wklr-mono/pull/8650/changes/BASE..0d909c90f9e2e42b20a9b5a6704b7542674fa097#diff-45e3a4cedee76b5b634ed98bc33dc144b642c83152f507d031c86001510fcb5aR62
> 
> ここでやってるんですが分かりづらいコードになっていると思うので、shouldDeployThumbnailの条件にしたいと思います

### PR #8460 · `packages/ccc-ui/tests/inputArticle.test.ts`

```diff
+  interface Window {
+    __submittedArticles: SubmittedArticle[];
+  }
+}
+
+/**
+ * docx を含む multipart はストリームで送られ、route ハンドラからは postData() も
+ * postDataBuffer() も null になる。送信内容を見るには fetch を包んで拾うしかない。
+ */
+const captureSubmissions = async (page: Page) => {
```
**Reviewer:**
> fetchの段階でキャプチャするよりリクエストを確認する / interceptするAPIがあるのでそちらを使った方が良さそう
**Author (著者が対応):**
> 対応しました。fetch を包んで送信内容を拾う方法はやめ、`page.route` で API を差し替えつつ `page.waitForRequest` で実際に飛んだリクエスト（送信先・メソッド・Content-Type）を確認する形にしています（`tests/articles.test.ts`）。

### PR #8460 · `packages/ccc-ui/tests/inputArticle.test.ts`

```diff
+};
+
+const submit = async (page: Page) => {
+  await page.getByRole('button', { name: '入稿' }).click();
+};
+
+// snackbar も role="alert" を持つため、フォーム内の結果表示に絞る。
+const resultAlert = (page: Page) => page.locator('form [role="alert"]');
+
+test('必須項目と Word ファイルを入力すると contents-api へ入稿する', async ({ page }) => {
```
**Reviewer:**
> E2Eどこまでやるか問題の議論になりますが、この網羅度でいくと今後のテストケースが膨大になり時間がかかりすぎるのではないかと思っています。入力パターンの全ケースをE2Eでテストする方針は避けたい気持ちがあるのですがどうでしょうか？
**Author (議論あり):**
> 同意です。入力パターンの網羅はやめ、`tests/articles.test.ts` は「登録して詳細画面へ遷移する」「Word 未選択なら送信しない」「SEC 未生成なら掲載不可で案内を出す」「SEC 生成済みなら掲載できる」「存在しない natural ID」の 5 件に絞りました。可否フラグの反転や日付の変換などの入力パターンは E2E では扱っていません。

### PR #8441 · `packages/gcs/tests/mem/file.test.ts`

```diff
+        const [copiedFile] = await sourceFile.copy(fsFile);
+
+        expect(copiedFile).toBe(fsFile);
+        await expect(fsFile.download()).resolves.toEqual([Buffer.from('copied to fs')]);
+      } finally {
+        fs.rmSync(tmpDir, { recursive: true, force: true });
+      }
+    });
+
+    it('should carry the content type to the destination', async () => {
```
**Reviewer:**
> これは何をテストしていますか？
**Author (著者が対応):**
> https://github.com/legalscape/wklr-mono/pull/8441/changes#diff-2e65ca00b18790421503d833cfedf06c34ed0193aab0c7379e38841c55e84fc1R44-R45
> 
> contentTypeの保存のテストなんですが、上のテストと統合し、getMetadataを使って確認するよう修正しました

## 8. 型定義・スキーマ設計

### PR #8833 · `packages/wklr-admin-api/src/service/seller.ts`

```diff
     if (!seller) {
       return new APIError(404, 'error.notFound');
     }
     return { data: SellerService.toSellerResponse(seller) };
   }
 
+  private async validateCode(code: string, selfId?: number): Promise<APIValidationError | undefined> {
+    if (code.length > SELLER_CODE_MAX_LENGTH || !SELLER_CODE_PATTERN.test(code)) {
+      return new APIValidationError({ code: { message: 'error.invalidSellerCode' } }, 'error.invalidSellerCode');
+    }
```
**Reviewer:**
> openapiのバリデーションでも同じことできそう？比較検討した上でいい方を選ぶと良いのかなと思いました。
**Author (著者が対応):**
> c557752 で OpenAPI 側に移しました。`code` に `pattern` / `maxLength` を追加して service の形式チェックを削除し、wklr-admin に `validation.openapi.pattern` / `maxLength` の訳を追加しています。重複チェックは service に残しています。

### PR #8423 · `packages/wklr-partner-api/src/utils/config.ts`

```diff
   li: {
     questionTopic: process.env.LI_QUESTION_TOPIC,
   },
+  reference: {
+    // /li/reference は account.* に置く（LI 連携専用のリンク解決エンドポイント）。
+    // ローカルでは account.* が引けないため REFERENCE_BASE_URL で上書きできるようにする。
+    baseUrl: process.env.REFERENCE_BASE_URL || `https://account.${process.env.LS_DOMAIN_SUFFIX}/li/reference`,
```
**Reviewer:**
> 【nit】`LS_DOMAIN_SUFFIX` が未設定の環境では `https://account.undefined/li/reference` という文字列になり、これは `z.string().url()` を通過してしまいます。`MASK_ENABLED = false` の間は実害ゼロ・有効化後も dev検証で即気づく類ですが、テンプレート組み立て前に `LS_DOMAIN_SUFFIX` の存在を確認するか、undefined を含む URL を弾くと、設定漏れが起動時に落ちるようになります。
**Author (著者が説明（現状維持 / 別途対応）):**
> `z.string().url()` を通ってしまう指摘のとおりです。[SV-6004](https://linear.app/legalscape/issue/SV-6004) に含めました（型名の nit と同じチケット）。`MASK_ENABLED = false` の間は `resolveReferenceLinkKey` が null を返して URL 自体が使われないので、優先度は Low で置いています。

### PR #8650 · `packages/wklr-migration/_schema/wklr_internal.sql`

```diff
   `version` INT unsigned NOT NULL COMMENT '同一document内でのバージョン',
   `natural_id` VARCHAR(255) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL COMMENT '各文書タイプでの意味のあるID。書籍であればISBN、法令であればelawsのID等。',
   `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
+  `is_exist_thumbnail` TINYINT (1) NOT NULL DEFAULT '0' COMMENT 'サムネイル画像が入稿されているかどうか',
```
**Reviewer:**
> 現状だと英語がおかしいので has_thumbnail はどうですか？
**Outcome:** 返信なし

## 9. セキュリティと認証・認可

### PR #8363 · `packages/wklr-auth2/client/pages/reset-password.vue`

```diff
+
+    const onNewPasswordInput = async (value: string) => {
+      newPassword.value = value;
+      submitError.value = null;
+      validateConfirmation();
+
+      const validationId = ++passwordPolicyValidationId;
+      // ポリシーの取得に失敗しても入力は続けさせる。ポリシーを強制する主体はサーバー側で、
+      // 違反していれば送信時に条件つきの文言が返る
+      const message = await validateNewPasswordPolicy($auth, value.trim()).catch(() => null);
```
**Reviewer:**
> 検証時だけtrimしているみたいなので空白をパスワードとして含むのであればtrim取り除いた方が良いと思います！
**Author (著者が対応):**
> ご指摘ありがとうございます。8d94e095 で `.trim()` を外しました。
> 
> 検証だけ trim した値をポリシーに掛けていて、送信は trim しない値を送っていました。末尾に空白を含むパスワードだと、検証している文字列と実際に設定される文字列がずれます（例: 8 文字目が空白のパスワードは 7 文字として検証され、サーバーは受理するのにクライアント側でエラーが出る）。
> 
> 同じく新しいパスワードを設定する `change-auth-provider.vue` は検証・送信とも入力値そのままを使っているので、そちらに揃える形にしています。

### PR #8665 · `packages/wklr-auth2/docs/bell-integration.md`

```diff
   participant A as wklr-auth2
   participant Auth0
   participant Firebase
-  U->>A: GET /auth/sso/auth0/start?return=...（bell の遷移リンク）
+  U->>A: GET /auth/sso/auth0/start?return=%2Fdocument%2F…（bell の文献リンク。return はホストを持たない絶対パス。切替リンクは return なし）
   alt 旧アプリのセッションが有効
-    A->>A: 復帰先組織へ既存 sessionId の端末を登録
-    A-->>U: 302 returnTo（Auth0 に触らない）
+    A->>A: 復帰先が組織ホストなら既存 sessionId の端末を登録
+    A-->>U: 302 returnTo（Auth0 に触らない。絶対パスなら /auth/login?organizationUndecided=1&return=<パス>）
```
**Reviewer:**
> これ/auth/login経由せずそのままreturnToに返せばよいのでは？
**Author (著者が対応):**
> ご指摘のとおり、直接 `returnTo` へ戻せます。account ホストの `/document/…` は Iris の `WklrBackendAPIConfig.fromRequest()` が既にログイン・組織確定へ委譲していました。「account ホスト上のパスでは組織が決まらない」という説明は、この既存処理を見落としていました。
> 
> 3f7434e27e で、SSO 無効・既存セッション有効・コールバック成功のいずれも検証済みの `returnTo` へ直接 302 する形に修正しました。クエリ・fragment もそのまま保持します。95e66025a6 で関連ドキュメントを …

### PR #8360 · `packages/wklr-auth2/server/util/legacySessionEstablisher.ts`

```diff
+  const sessionId = readSessionIdCookie(req) ?? uuidv4();
+
+  let idToken: string;
+  try {
+    const customToken = await withAuthHttpTimeout(() => admin.auth().createCustomToken(firebaseId, { sessionId }));
+    idToken = await exchangeCustomTokenForIdToken(customToken);
+  } catch (error) {
+    logger.error(`ID トークンの取得に失敗しました: firebaseId=${firebaseId}`, error);
+    return { ok: false, reason: 'failed' };
+  }
```
**Reviewer:**
> exchangeCustomTokenForIdTokenはリクエスト bodyに
> 
> ```json
> {
>   token: customToken,
>   returnSecureToken: true
> }
> ```
> 
> を含むそうなので、errorを丸ごとlogするのはやめたほうが良さそうですかね？
**Author (著者が対応):**
> errorをラップする方針になったようです！

### PR #8423 · `packages/wklr-backend-api/src/services/LiService.ts`

```diff
+  /**
+   * LI 文献リンク（iris の `/li/reference`）が遷移先を決めるための連携先ポリシーを返す。
+   *
+   * **⚠️ このエンドポイントと `LiClientPolicy` entity は前例にしないこと。** 連携先の設定を持つのは
+   * wklr-partner-api で、リンク解決を iris に置いた代償として受け入れた外れ値である。詳細は
+   * `models/LiClientPolicy/entity.ts`。
+   *
+   * 認証を要求しない。`public_id` は連携先のエンドユーザーに配るリンクのクエリパラメータで、
+   * 返す 2 bit は未認証で辿れる `/li/reference` の遷移を観測すれば判るため（SV-5894 は取り下げ）。
+   * **返すのが 2 bit だけという前提に依存する**ので、カラムを足すときは再検討する。
```
**Reviewer:**
> 【提案】「返すのが 2 bit だけという前提に依存するので、カラムを足すときは再検討する」は、判断基準そのものを書いた方が将来の変更に効くと思います。認証なしが許される根拠は「返す値のすべてが、未認証で辿れる `/li/reference` の遷移を観測すれば判る情報であること」なので、例えば「認証を通さないこの応答に、`/li/reference` の遷移の観測から判らない情報を足してはいけない（例: 連携先の名前・billing model・book_list_key は観測不能な内部情報なので不可。遷移の分岐に直接現れる bool は可）。足す必要が生じたら認証の付け直しか partner-api 側への移設とセットで行う」のように、可否の判定基準と具体例まで書いておくと、「2 bit」という量の制約ではなく質（観測可能性）の制約であることが将来の編集者に伝わります。
**Author (著者が対応):**
> 「量（2 bit）ではなく質（観測可能性）の制約」という整理はそのとおりで、認証を外した判断の根拠そのものなので `da799ebb5b` で書き換えました。判定基準（`/li/reference` の遷移の観測から判らない情報を足してはいけない）と、可否の具体例（遷移の分岐に直接現れる bool は可 / 連携先名・`billing_model`・`book_list_key` は不可）、足す場合は認証の付け直しか partner-api 側への移設とセットで行うこと、まで残しています。

## 11. ドキュメント・レビュープロセス・コミュニケーション

### PR #8618 · `docs/design-docs/wandh-overseas-research.md`

```diff
+
+パースは**未知フィールドを無視し、必須欠落だけをエラーにする**。`title` 以外はすべて optional なので、`url` / `snippet` / `citation_index` の欠落でリクエスト全体を失敗させない。`search_results` が空配列でも `generated_text` があれば成功として扱う（参照文献ゼロの回答は起こり得る）。
+
+### 同期を採る理由と、ストリーミングへの移行余地
+
+初期は `stream=false` を採る。
+
+| 観点 | 同期（採用） | SSE 中継（見送り） |
+| --- | --- | --- |
+| 実装 | 既存の非ストリーミング API と同じ | backend-api で SSE 中継が必要。国内の「iris → wandh 直結」とは別方式をもう 1 つ持つことになる |
```
**Reviewer:**
> cloud runでSSE中継できるのでやった方が良いと思います。 wandhもこの方式に切り替え予定なので揃います。
**Author (著者が対応):**
> 互換じゃないので JSON でいいかなと思ってたのですが、もう一回確認したら互換だったので SSE化しました。
> 
> 調査内容
> https://github.com/legalscape/ls-gist/blob/main/tsaito/allibee_rag/SSE.md

### PR #8618 · `docs/design-docs/wandh-overseas-research.md`

```diff
+| カラム | 型 | 内容 |
+| --- | --- | --- |
+| `id` | BIGINT UNSIGNED | lsid。`questionId` |
+| `history_id` | BIGINT UNSIGNED | `labs_wandh_question_history.id` への FK |
+| `user_id` | BIGINT UNSIGNED | `user.id` への FK |
+| `jurisdiction` | VARCHAR(8) | 例: `KR` |
+| `provider` | VARCHAR(32) | 例: `BHSN` |
+| `query` | TEXT | ユーザーの質問文 |
+| `databases` | JSON | 連携先に送った `databases` |
+| `enable_web_search` | TINYINT(1) | 連携先に送った値 |
```
**Reviewer:**
> これはallibee固有値？ parameters: jsonみたいな感じで持っておいた方が良いですかね？
**Author (著者が対応):**
> 確かに・・・ allibee 固有なので databases とまとめて request_parameters: JSON に変更しました。

### PR #8660 · `packages/wklr-backend-api/docs/content-rate-limit.md`

```diff
+# コンテンツ取得の初期限界
+
+現行Irisの本文チャンク取得は248リクエスト/分、wklr-backend-apiのsingle-page-pdf取得は400リクエスト/分まで、認証済みユーザー・組織単位で許可する。ポリシーごとに暦分の固定窓で数え、超過時は429とRetry-Afterを返す。失敗した取得も数える。
+
+Irisは`/.iris/api/v0/docs/{id}/chunks/{chunkId}`を受けるたび、アクセス確認APIへ`x-ls-content-read-policy: iris-document-chunk`を付けて呼び出す。wklr-backend-apiはアクセス確認と同じ認証情報を使って枠を確保してから結果を返す。このため、IrisのCloud RunサービスアカウントにDatastore権限を追加する必要はない。旧LS2の`/documents/{id}/sections/*`は現行Irisから呼ばれていないため対象外とする。
```
**Reviewer:**
> [review-guide] 【要対応】 sections 系3経路と bulk の上限が未対応。まとめて取れる経路が素通しになっている
> 
> > 旧LS2の`/documents/{id}/sections/*`は現行Irisから呼ばれていないため対象外とする。
> 
> この除外理由は「正規クライアントが使っていない」という話で、「攻撃者が使えない」という話ではないと思います。本チケットの背景は大量の連番閲覧なので、想定している相手は正規 UI を経由しません。
> 
> 確認したところ、
> 
> - `SectionsController.ts` は3メソッドとも `DefaultController.handleRequest(request, response, service.xxx)` をオプション無しで呼んでおり、本PRで未変更
> - `api/openapi.yaml` の該当3パス（797 / 833 / 897 行）に `x-ls-required-permissions` も `x-ls-endpoint-skip-auth` も無い。**認証さえ通っていれば、どの組織のどのユーザーでも追加権限なしで呼べます**
> - レスポンスは `DocSection` の配列 = 本文コンテンツその …
**Author (著者が対応):**
> ご指摘のとおり、正規クライアントが未使用でも直接呼び出しを防ぐ必要があります。3つのsections経路へ専用ポリシー（64回/分）を追加し、bulkのkeysと前後marginを最大20に制限しました。3経路すべてへポリシーが渡るテストも追加しています（2adc217ccb）。

### PR #1904 · `labs-wandh/wandh/watson/law.py`

```diff
+
+
+def replace_kanji_numerals(match: re.Match) -> str:
+    s = match.group()
+    n = kanji_to_int(s)
+    return str(n)
+
+
+def kanji_to_numeric_in_text(text: str) -> str:
+    return re.sub(numeric_pattern, replace_kanji_numerals, text, count=1)
```
**Reviewer:**
> 追いきれてないんですがここってなぜ count=1 なんですか？
**Author (著者が説明（現状維持 / 別途対応）):**
> はい、例外のケースもありますが、それらはそのままでいいと思っていました。元々この変換がしたい理由は漢字が長いから読みにくいでして、この場合は長さがほとんど変わりませんし。

## 12. 状態管理と非同期処理

### PR #8595 · `wandh/src/agents/shared/state.py`

```diff
     gemini_query_embeddings: NotRequired[list[list[float]] | None]
     """Gemini Embedding によるクエリベクトル。
 
-    法令検索 (law_search) でのみ消費される。gemini_embedding ノードを graph に
+    法令検索 (law_search) と裁判所判例検索で消費される。gemini_embedding ノードを graph に
```
**Reviewer:**
> すごいnitなんですけど裁判所判例検索の後に、law_searchと並ぶような（）があって欲しい気がしました（ざっと眺めていて目に入った）
**Author (著者が対応):**
> 裁判所判例検索 (case_courtsgojp_search) に修正し、法令検索の表記と揃えました。

### PR #8649 · `packages/wklr-partner-api/src/utils/outboundReferences.ts`

```diff
+const isNoop = (context: OutboundReferenceContext): boolean =>
+  context.visibleKeys === null && context.publicId === null;
+
+function applyToReferenceData(
+  data: Record<string, unknown>,
+  context: OutboundReferenceContext,
+): Record<string, unknown> {
+  const { visibleKeys } = context;
+  const filtered = visibleKeys === null ? data : filterReferenceData(data, visibleKeys);
+  return transformsAfterFilter(context).reduce((current, transform) => transform(current), filtered);
```
**Reviewer:**
> 端的にいうとリファクタした割に処理が複雑になっているなと思っていて、
> 現在はfilterとmaskするの二種類しかなくて、そしてfilterは絶対に最初に来てほしいというのであれば、
> transformsAfterFilterはせずにただ順番に書き下せば良いのかなと思います。
> AI的にはコメントとかプロンプトで説明したがるみたいですが、極力コードでその順番を明快に記述したいです。関数の層が分厚くなって、（きっとAIにも）何をどう保証してほしいのかわかりづらい気がします。
> 
> claudeに出してもらったイメージ
> ```
> export type OutboundReferenceContext = { publicId; visibleKeys; referenceBaseUrl };
> 
> export function resolveOutboundReferenceContext(policy, referenceBaseUrl) { /* 現状のまま */ }
> 
> /** 履歴経路（A2A envelope を持たない） */
> export function prepareOutboundReferenceData(data, context) {
>   const { visibleK …
**Author (著者が対応):**
> 2 点とも入れました（`0a31f42`）。フラグを立てた状態での確認までありがとうございます。
> 
> ### 1. `referenceBaseUrl` を第 3 引数に戻した
> 
> `utils/` で `config` を読んでいるのがインフラ系 3 つだけ、というのは見ていませんでした。「注入をやめたわけではなく 1 段内側にずれた」もそのとおりで、同じ値について境界の外では引数、内では直読みが同居する形になっていました。`config.ts` が読み込み時に `parse()` を走らせる点も含め、戻すのが正しいです。
> 
> 呼び出し側 4 箇所が `config.reference.baseU …

## 13. タイムゾーン・日付・国際化

### PR #8577 · `packages/wklr-admin/src/components/PublicationPeriodDateInput.tsx`

```diff
+function toPublicationPeriodDatetime(jstDate: string, boundary: PublicationPeriodBoundary): Date | null {
+  if (!JST_DATE_SHAPE.test(jstDate)) {
+    return null;
+  }
+  const built = new Date(`${jstDate}T${fixedTimeJst(boundary)}+09:00`);
+  if (Number.isNaN(built.getTime())) {
+    return null;
+  }
+  // 存在しない日付は翌月へ繰り上がる
+  return toJstDate(built) === jstDate ? built : null;
```
**Reviewer:**
> (質問)
> ここの処理って「存在しない日付を入れると勝手に繰り上がるから、その場合は空として返している」って理解であっていますか。
**Author (議論あり):**
> その通りです。

### PR #8681 · `packages/wklr-backend-api/src/models/LabsWandh/index.ts`

```diff
+        return 'alreadyConsumed';
+      }
+      if (reserved.expiresAt < new Date()) {
+        logger.warning(`期限切れの予約クオータを消費しようとしました。id=${reservedQuotaId}`);
+        return 'expired';
+      }
+
+      // modelSelection は NULL を取り得る（旧データ）。国内の残数計算と同じく advanced として扱う
+      const modelSelection = (reserved.modelSelection ?? LabsWandhModelSelection.advanced) as LabsWandhModelSelection;
+      const quota = await this.findOrCreateQuota(repos, organization, user, modelSelection, planWithType);
```
**Reviewer:**
> `LabsWandh/index.ts` の648〜657行では予約時の契約情報を保存していますが、`consumeReservedQuota` は734行で消費時点のプランを取得し、760行から呼ぶ `findOrCreateQuota` は791〜835行で現在月・現在契約のクオータを探します。月末に作った予約が翌月に完了すると翌月分を消費し、既存ジョブの計上先とも異なります。予約行の `createdAt` と契約情報を使って計上してください。
**Outcome:** 返信なし

## PR-level review summaries (how approvals and pushbacks are worded)

### PR #8837 · COMMENTED
> 基本的に良いと思う&私が追いついていないだけなのですが、私の理解のために以下の質問に答えていただけますと。
> 
> 1. チャンクの切り方のハイパーパラメーターについて
> 最初200トークン、600トークン目安と読み取りました。このハイパーパラメーターをどのようなロジックで決めたのか教えていただけますか？書籍がこうだからなど、何かしらの理由付けがあれば十分です。
> 
> 2. チャンクに記事のタイトルや見出しを投入
> ある種のコンテキストとして良い実装だとは思いつつ、記事のタイトルや見出しが長いものがあった場合に、チャンクがあまりに似すぎてしまうなどがあるのかなとも思いました。タイトルや見出しの長さに対して、本文の長さがどれぐらいだから大丈夫そうなど、検討されていたら教えてほしいです。**1.に関連**
> 
> 3. article.sec に保存する
> 受け取るのはRSECかなと思ったんですが、それを .sec として保存するので問題なかったでしたっけ。

### PR #8792 · APPROVED
> ［任意］commitは成功したものの、レスポンスを受信できずタイムアウトしたケースもテストに追加するとよさそうです。retry時に保存済みnonceを検出し、`False`（middlewareでは401）を返すことを確認できると、安全側に拒否する挙動が明確になります。

### PR #8757 · APPROVED
> FYI: MHMポータルは許可ログが出ないため、対象APIで429が発生すると集計値が偏る可能性があります。エッジケースなので追加対応は不要です。一旦進めて、実ログとグラフの表示を確認してみてください。

### PR #8757 · APPROVED
> FYI: パスのマスクは /multipass/:token/ のような末尾スラッシュ付きだと効かないため、対象を広げる余地があります。通常はリダイレクトで終わる経路なので、このPRでの追加対応は必須ではありません。

### PR #8520 · APPROVED
> 修正ありがとうございます。前回のコメント 4 件は、どれも意図どおりに直っていることを確認しました。approve します。
> 
> あわせて 2 点、共有させてください（どちらもこの PR のマージを止めるものではないです）。
> 
> 1. 判例の処理バージョンのフィールド名
> 法令とガイドラインは proc_version に揃いましたが、main にある判例の CaseCourtsgojpReferenceMetadata は processing_version のままなので、watson_reference の共通モデルには同じ意味のフィールドの名前が 2 通り残っています。判例側の変更になるので、別 PR で揃えてもらえると嬉しいです。（前回のコメントで判例に触れていなかったのは、こちらの見落としでした🙏）
> 
> 2. ES の proc_version が空文字だった場合の扱い
> 問題ないか確認してもらえると嬉しいです。
> retriever は source.get("proc_version", "v1") で読んでいるので、キーが無いときは v1 になりますが、空文字のときは "" のままになると読みました。#8853 では indexer が chunk.proc_version or "" と書き込んでいるので、chunk.proc_version が None になる経路がある …

### PR #8872 · COMMENTED
> 細かいですが、W&HとUIを合わせた方が良さそうで、
> - watson側の選択状態もタイトルが緑色になる方が良さそう
> - watson側の選択されたスニペットのスクロール位置は上部ではなく中央が良さそう

### PR #8723 · COMMENTED
> isCitedはoptionalのままの方が良いかもです！
> 
> json rpcのstream時にisCitedがない状態で一度responseを返してその後にisCitedを入れた状態で同じデータを返すという挙動をしていたと思います 🤔

### PR #8723 · COMMENTED
> `"publisher", "publishedDate",`<br><br>すみません、web,lawもこの二つって必須で入っているんでしたっけ？ lawが怪しい気がしまして……
