# Review examples mined from legalscape/bell

Source: 20 inline review threads and 46 PR-level comments from 44 merged PRs (humans only; author, bots and bare approvals removed). Each example is: the hunk the reviewer pointed at → what they said → what the author did. `AI-assisted` marks comments posted with an AI assistant footer; they count for substance, hand-written ones also for tone.

| # | category | threads |
|---|---|---|
| 1 | 命名・可読性・コード品質 | 0 |
| 2 | アーキテクチャと設計 | 9 |
| 3 | UI/UX とデザイン実装 | 0 |
| 4 | CI/CD・ビルド・依存関係・環境 | 0 |
| 5 | ドメインロジック・データ整合性・DB | 1 |
| 6 | エラーハンドリング・バリデーション・堅牢性 | 0 |
| 7 | テストとカバレッジ | 6 |
| 8 | 型定義・スキーマ設計 | 0 |
| 9 | セキュリティと認証・認可 | 0 |
| 10 | パフォーマンスと最適化 | 0 |
| 11 | ドキュメント・レビュープロセス・コミュニケーション | 4 |
| 12 | 状態管理と非同期処理 | 0 |
| 13 | タイムゾーン・日付・国際化 | 0 |

## 2. アーキテクチャと設計

### PR #627 · `doyle/packages/doyle-core/src/doyle_core/workflows/deep-research.yaml`

```diff
       - report
     config:
       model: gpt-5.6-luna
+      thinking_level: high
```
**Reviewer:**
> 処理時間はそこまでセンシティブになる必要はないとは思いますが、モデル既定（reasoningなし？）からhighに設定したことでやや時間が増加するはずだと思うので、今後処理時間が気になったらいじるものとして、頭の端に入れておきたいと思いました。
**Author (議論あり):**
> Deep Researchは今早すぎてDeep感がなかったのでちょうど良いのでは？と勝手に思っていますw

### PR #514 · `doyle/packages/doyle-core/src/doyle_core/features/highlight/encoder.py`

```diff
 
     bm25 = BM25Encoder()
     bm25.load(str(bm25_params_path))
-    tagger = Tagger("-Owakati")
+    tagger: Any = _Tagger("-Owakati")
```
**Reviewer:**
> コメント：ぐぬぬ...僅かに気になり、理想的には直したいですが、外から参照されないし小さい部分なので無視しました
**Author (著者が対応):**
> 細かい点はStrict対応後にどんどん直していきたいです。

### PR #493 · `doyle/packages/doyle-core/tests/features/legal_search/infra/test_execution_policy.py`

```diff
     text: str
 
 
+class _StructuredOutputRunnable(Protocol):
+    """`with_structured_output` が返す runnable。deps の非公開 Protocol と同じ形。"""
+
+    async def ainvoke(self, input: Any, config: Any = None, **kwargs: Any) -> Any: ...  # noqa: A002 - Protocol の引数名
```
**Reviewer:**
> nitsですが、ここ以外に4件ほどあるので消しておきたい気持ちになりました。
> > \# noqa: A002
> > doyle-core の ruff 設定（select = ["B904", "E4", "E7", "E9", "F", "TID251"]）では対象ルールが無効なので何も抑制していません。--ignore-noqa（noqa が無いものとして検査）を両ファイルに当てて All checks passed! を確認済みです。
**Author (著者が対応):**
> ご指摘どおり doyle-core の ruff では対象外で何も抑制していなかったので、この PR で足した分（A002 ×4・N802 ×1）を 084a72b3 で削除しました。main に元からある同種の noqa は PR の範囲外として残しています。

### PR #307 · `doyle/packages/doyle-core/src/doyle_core/features/legal_search/domain/models.py`

```diff
-DOCUMENT_TYPE_BY_REFERENCE_TYPE: dict[str, DocumentTypeName] = {"case": "case_d1"}
-"""SearchFilter が受け付ける reference_type の別名。両語彙が食い違う文書種別だけを持つ。"""
+class _SnippetMetadata(BaseModel):
+    """種別固有 metadata の共通基盤。"""
+
+    model_config = ConfigDict(extra="forbid")
+
+
+class LawSnippetMetadata(_SnippetMetadata):
+    article_label: str | None = None
```
**Reviewer:**
> Metadataにコメントで良いので、日本語の説明文+具体例だけ書いてもらえないでしょうか🙏
> せっかく分かりやすくしていただいたので、ぱっと見の意味がわかるようにしておきたい趣旨です。
**Author (著者が対応):**
> a10aba39 で対応しました。Metadata の各フィールドに、日本語の説明 + 値の例をコメントで付与しました。例はテストの fixture にある値が良さそうだったので、そこから取っています。

## 5. ドメインロジック・データ整合性・DB

### PR #531 · `doyle/packages/doyle-core/docs/ARCHITECTURE.md`

```diff
 | ------------- | -------------------------------------------------------------------------------------------------------- | ---------------------- |
 | テキスト系    | そのまま読む                                                                                              | text へ切替（警告付き） |
 | DOCX          | 自前 OOXML 抽出（stdlib のみ・レンダリングなし。本文・表・ヘッダ / フッタ・脚注・文末注・コメントを markdown 化） | text へ切替（警告付き） |
-| PDF           | 直接テキスト抽出のみ。OCR で代替しない（OCR は課金経路で別の問いに答えるため、無効なら代替せずその旨を返す）       | OCR / vision           |
+| PDF           | 直接テキスト抽出のみ。vision で代替しない（vision は課金経路で別の問いに答えるため、無効なら代替せずその旨を返す） | vision                 |
```
**Reviewer:**
> Claudeが発見しましたが、これ自体はPRのスコープ外なので、non-blockingです：
> 
> 指摘（要修正）: 「text 要求から vision へ自動で切り替えない」という説明が仕様と逆になっています
> 
> ARCHITECTURE.md の PDF の text モード欄と、test_read_pdf.py 冒頭の docstring を、「スキャンページがある場合だけ vision に自動で切り替える」という内容に直してください。
> 
> - 実際の挙動: PdfReadSettings.auto_recover_scans は既定で True です。スキャン判定（mostly_image_page）のページを含む PDF は、text で要求しても vision で読み直されます。この挙動は test_read_scan_recovery.py（test_scan検出後は既定の五ページを画像として返す など）で仕様として決まっています。
> - 原因の推測: 変更前の「OCR で代替しない」は正しい説明でした。自動回復は元々 vision だけを使っていたためです。「OCR」を「vision」へ機械的に置き換えたことで、意味が逆になったと思われます。
> - 修正案:
> ▎ 直接テキスト抽 …
**Author (著者が対応):**
> 上記だけ対応します！

## 7. テストとカバレッジ

### PR #526 · `doyle/packages/doyle-core/tests/executor/agent_tools/test_read_resource_limits.py`

```diff
         mime_type=mime,
         metadata={"bytes": b"1234"},
     )
-    result = await manager._uploaded_or_reader_bytes(resource, purpose="test")
-    assert isinstance(result, dict)
+    manager = ReadResourceManager(settings=settings, resources=[resource])
+    mode: AgentReadMode = "vision" if mime.startswith("image/") else "text"
+    result = await manager.read(filename, mode)
+    assert result["ok"] is False
```
**Reviewer:**
> 以下claude のコメントですが、合っていそうな気がするので確認してみていただきたいです🙏
> 
> read() 経由への書き換えで、元のテストが固定していた「ルート処理前（_check_source_bytes）で拒否する」ことを検証しなくなっています。ローカルで _check_source_bytes の拒否を無効化してみたところ、PNG・JPEG・DOCX のケースはルートごとの判定で拒否されるため、そのまま通りました（落ちたのは、ルートごとの判定を持たない PDF だけです）。
> 
> また、read() 経由での PNG・DOCX の上限超過は、既存の test_read_image.py::test_image_over_max_bytes_is_rejected_before_decode と test_read_docx.py::test_docx_over_max_bytes_is_rejected_before_extraction ですでに検証されていて、重複しています。
> 
> もしルート処理前の判定を仕様から外すのが意図的でないなら、LAB-962 の範囲（parametrize に image/jpeg を追加）に合わせて、元の test_source_over_limi …
**Author (著者が対応):**
> 対応してみました！

### PR #472 · `packages/bell-web/test/ui/followup-suggestion.spec.ts`

```diff
+    await evidenceWhen(page, "会話をリロードした直後", async () => {
+      await page.reload();
+    });
+    await evidenceThen(page, "候補が同じ順序で復元され選択できる", async () => {
+      await expect(candidates.getByRole("button")).toHaveText(followupQuestions);
+      await expect(candidates.getByRole("button").first()).toBeEnabled();
+      return candidates;
+    });
+  });
+  test("completion 前の SSE 候補は履歴にまだなくても disabled で表示される", async ({ page }) => {
```
**Reviewer:**
> https://ci-artifacts.devops.legalscape.dev/legalscape/bell/35195722897/all-diff/allure-report/index.html#5be3e8396ab89a14c240d8bfc712a6de
> 
> ユーザー的にはなんでとなりそうな挙動
**Author (著者が対応):**
> 一応 更問フォームが入力できないときにこの状態になります。テストの画面はテスト用にありえない順番でeventを出しているっぽいです。テストわかりやすいように修正します

### PR #501 · `packages/bell-web/test/ui/review.spec.ts`

```diff
+    const said = page.getByTestId(`review-decision-comment-${reviewId}`);
+    await expect(said).toHaveAttribute("data-turn-type", "user");
+    // 質問の吹き出しと同じ組み立て（同じ class = 同じ配置・同じ見た目）になっている。
+    const question = page.getByTestId("turn-user-0");
+    expect(await said.getAttribute("class")).toBe(await question.getAttribute("class"));
+    // 時刻は質問と同じ `MM/DD H:MM` 形式で吹き出しに添う。
+    await expect(said.getByText(/^\d{2}\/\d{2} \d{1,2}:\d{2}$/)).toBeVisible();
+  });
+
+  test("承認した決定は何も残さない（依頼文も定型文も消える）", async ({ page }) => {
```
**Reviewer:**
> 「承認した」という旨は出ていた方が新設かなという気はしましあｔ
**Author (議論あり):**
> 一旦デザインに合わせて消しています！
> ステップが進むということは承認されたということを暗に示しているという理解をしています。

### PR #493 · `doyle/packages/doyle-core/tests/features/legal_search/infra/test_retrievers_pinecone.py`

```diff
 
     class FakeIndex:
-        def query(self, **_kwargs):
+        def query(self, **kwargs: Any) -> dict[str, Any]:
+            del kwargs
             return {"matches": []}
 
     class FakePinecone:
-        def Index(self, _index_name: str) -> FakeIndex:
+        def Index(self, name: str) -> FakeIndex:  # noqa: N802 - SDK の公開名
```
**Reviewer:**
> > `noqa: N802`
> 
> `A002`と同様に、これも ruff の検出対象に入っていないので不要のようです
**Author (著者が対応):**
> こちらも 084a72b3 で削除しました。

## 11. ドキュメント・レビュープロセス・コミュニケーション

### PR #472 · `docs/requirements/followup-suggestion.md`

```diff
+| FR-014 | 非正常終端では起動しない  | もし実行が失敗または停止で終端したならば、システムは、更問サジェストの生成を開始しないこと。終端前に受理済みの候補も、失敗・停止の確定後は表示・履歴返却しないこと            | Must   | UC-003 / 質問ラウンド1         | [確認済み] |
+
+### 受け入れ基準
+
+#### FR-001（完了時・終端前の生成起動）
+
+| AC ID     | 区分   | Given                                     | When                 | Then                                                 | テスト層 |
+| --------- | ------ | ----------------------------------------- | -------------------- | ---------------------------------------------------- | -------- |
+| AC-001-01 | 正常系 | 成果物を 1 件以上生成するワークフロー実行 | 実行が正常に完了する | 完了ハンドオフを入力に生成が 1 回起動される          | E2E      |
+| AC-001-02 |        | 成果物を 1 件以上生成する Free chat 実行  |                      | 完了ハンドオフを入力に生成が起動される               |          |
```
**Reviewer:**
> 成果物を生成しないフリーチャットの時にどうなるかが気になるが大丈夫だろうか
**Author (議論あり):**
> フリーチャット自体にサジェストを入れないという話も出た気がするのですが、結論ワークフローの終端には入れるという話になった気がしていて今は入れています……

### PR #472 · `docs/requirements/followup-suggestion.md`

```diff
+| --------- | ------ | --------------------------------------- | ---------------------------------------- | --------------------------------------------------- | -------- |
+| AC-003-01 | 正常系 | 質問候補 3 件を載せた境界 IF のイベント | 契約スキーマで検証する                   | 生成元の実行を特定する識別子を含んで parse 成功する | 契約     |
+| AC-003-02 |        | 更問サジェストの共有フィクスチャ        | bell と doyle の双方のスキーマで検証する | 双方で parse 成功する                               |          |
+
+#### FR-004（件数と文字数の契約検証）
+
+| AC ID     | 区分   | Given                               | When            | Then                                   | テスト層       |
+| --------- | ------ | ----------------------------------- | --------------- | -------------------------------------- | -------------- |
+| AC-004-01 | 境界   | 項目 5 件のセットを載せたイベント   | bell が受理する | 5 件が永続化される                     | エンドポイント |
+| AC-004-02 |        | 項目 6 件のセットを載せたイベント   |                 | セット全体が破棄される                 |                |
```
**Reviewer:**
> 5件に切り詰めるとかでよい気が 🤔
**Author (議論あり):**
> 切り詰めに変えます！

### PR #472 · `docs/requirements/followup-suggestion.md`

```diff
+| AC-003-02 |        | 更問サジェストの共有フィクスチャ        | bell と doyle の双方のスキーマで検証する | 双方で parse 成功する                               |          |
+
+#### FR-004（件数と文字数の契約検証）
+
+| AC ID     | 区分   | Given                               | When            | Then                                   | テスト層       |
+| --------- | ------ | ----------------------------------- | --------------- | -------------------------------------- | -------------- |
+| AC-004-01 | 境界   | 項目 5 件のセットを載せたイベント   | bell が受理する | 5 件が永続化される                     | エンドポイント |
+| AC-004-02 |        | 項目 6 件のセットを載せたイベント   |                 | セット全体が破棄される                 |                |
+| AC-004-03 |        | 200 文字の項目 1 件を載せたイベント |                 | 1 件が永続化される                     |                |
+| AC-004-04 | 拒否系 | 201 文字の項目を含むイベント        |                 | セット全体が破棄される                 |                |
```
**Reviewer:**
> これも全体を破棄する必要はなさそう？
**Author (議論あり):**
> 201文字以上の項目だけ破棄します（これは切り詰めると質問文としては成立しなくなるため）

### PR #441 · `docs/requirements/reference-sidebar.md`

```diff
ng し、doyle-core の対応表で連番ラベル（`[CITE: S1]`）を引用キーへ変換してから `workproduct_delta` を publish する（§8。仕様は doyle-app のテスト `TestWorkproductDeltaBuffering`）。bell には引用キーのマーカーだけが届き、断片で割れたマーカーも届かない。リンクにできないマーカー（未到着の引用キー・残った仮ラベル・断片末尾の未閉じ）の非表示は bell-web の責務（FR-025 / FR-028）で、doyle-app では重ねて削らない。 | doyle-app の変換が外れると bell に S ラベルが届き、生成中の引用リンクが出なくなる（防御で非表示にはなる）。文境界の定義が bell-core とずれると、主張文の切り出し（FR-030）と生成中の断片の区切りが食い違う（共有フィクスチャ `contracts/claim-sentence.fixture.json` が両言語を固定する）。 |
 | ASM-011 | 表示文言は初出順の連番       | 引用リンクの表示文言は成果物内の初出順の連番とする（OPEN-002 の決定までの仮置き。W&H の既定表示と同じ）。                                                                                                                                                                                                                                                                                                                                                                            | AC-012-02 とコンポーネントテストの期待値が変わる。連動（FR-013）は変わらない。                                                                                                                                                                                                              |
-| ASM-012 | 対象は Markdown 成果物のみ   | 引用リンク化の対象は Markdown renderer の成果物本文に限る。認否（ninpi）renderer の本文と発話（agent_talk）は、doyle 側で引用マーカーを保存時に内容ハッシュへ正規化する経路が同じでも、PH-002 では変換しない。                                                                                                                                                                                                                                                                       | AC-012-09 が変わる。認否・発話の描画コンポーネントにも置換を通す追加スライスになる。                                                                                                                                                                                                        |
+| ASM-012 | 認否の本文だけ対象外         | 引用リンク化の対象は Markdown renderer の成果物本文・エージェントの発話（agent_talk）・認否（ninpi）renderer の項目が持つ出典ラベル（`sources`）。認否の本文（`content`）だけは変換しない — 部分認否の範囲を数える文字列なので、記法を落とすと保存済みの範囲が別の位置を指す。                                                                                                                                                                                                       | AC-012-09 が変わる。認否の本文にも置換を通すなら、部分認否の位置を記法込みで数える設計が要る。                                                                                                                                                                                              |
```
**Reviewer:**
> （口頭で確認）
> 別PRで消える。つまり、マーカーが置換されるようになる。
**Outcome:** 返信なし

## PR-level review summaries (how approvals and pushbacks are worded)

### PR #628 · APPROVED
> 良さそうです。 変更内容を丁寧めに確認しましたが、特に指摘事項ありませんでした 🙆‍♂️
> test も網羅されていそうに見えます。

### PR #610 · APPROVED
> 良さそうに見えます！ToolNodeは「doyleで使用可能なツールのセット」であり、状況に応じたツールの利用可否は、LLMに見せるtool schemaで、以下の仕様で動的に変更する機能だと理解しました！よい機能だと思います！
> availabilityの登録なし -> LLMに見せる
> availability: true -> LLMに見せる
> availability: false -> LLMに見せない

### PR #604 · APPROVED
> 良さそうです 🙆‍♂️  もう割とどのLLM Providerでも新しい世代のモデルではtemperatureを受け付けないようになっているの知らなかったです。

### PR #597 · APPROVED
> 変更内容良さそうで、mergeをブロックするようなコメントはないです 🙆‍♂️ 
> １点確認で、linear issue の方には、eventに記録する内容として「user edits の有無」を挙げていましたが、このPRには含まれていません。これが意図的かどうか一応確認しておきたいです🙏

### PR #603 · APPROVED
> 良さそうです！temperatureが0なら再試行して回答拒否が改善するかわからないかも？と思いましたが、gpt-5.6ではtemperatureは設定できないんですね〜なるほど。他にも失敗する要因はあるし改善する可能性もあるので、再試行自体は必要だと思いました！

### PR #459 · COMMENTED
> これ単体ではベースラインとして良さそう、一つ前のPRが修正されたら再度確認したい。
> 
> pypdfium2に揃えたら楽なのかと思っている

### PR #402 · APPROVED
> yaml調整後で再度軽く実行して、心配していた「法令への引用（S）が薄くなる」は、大部分が yaml 変更のせいで解消したと思われる。
> 
> ベースラインとしての変更はOK 
> 
> Plz merge at your convinience
> 
> ーー
> **AIが細かいこと言っていますが、このPRで直す必要はない**　軽く見てもらって、重大そうなら別PRで
> 
> - hash mode の不整合。読取ツールは hash mode でも引用 ID を返すのに、指示文は「添付を引用しない」のまま。既定は sequential なので実害は無い。hash mode では ID を返さないようにして揃える。
> - free chat の handoff が引用元を全部コピーする。過去の run から継承した引用元まで毎回保存するので、セッションが長くなるほど handoff が肥大する。この run で新しく登録した分だけ保存すればよい。
> - 全ノードの prompt に空の引用リストと注意書きが入る。tool を持たないノードにも入る。S 減少の一因の可能性があるので、S 対応と一緒に見直す。

### PR #390 · APPROVED
> 上限値は今後調整する＋アプリ側でも制限されるのでおそらく大丈夫ではあるが、リソース上限が設ける方向はAgree。
> 
> **コメント対応したら適宜mergeください**
> 
> - visionはpdftoppmとかを入れないと動かないと思っています（今はvision使ってないから関係ない）
> - 以下の制約が入ったと理解しました（PR本文とはずれているっぽいけど）
> 
> 
> 境界 | 追加された制限 | 主な値
> -- | -- | --
> 入力 / resume | 文字数・バイト数・コレクション件数・深さ | 1M chars、10MB、500 件、depth 32、resume 64MB
> 編集バッチ | 操作数・引数バイト・置換後の成果物サイズ | 128 件、64MB、成果物 8MB
> 成果物保存 | 1 件と batch の上限を保存開始前に全体検証 | 8MB / 件、500 件、32MB
> 保持文脈（handoff） | 1 件と合計の上限、連続する直近 suffix だけ保持 | 16MB / 件、合計 64MB、50 件
> hydration | 成果物本文の読込に共有予算（件数・バイト） | 500 件、64MB
> DOCX | ZIP 件数・展開量・XML 深さ / ノード / セル・DTD 拒否・出力量で部分読取 | 展開 100MB、depth 64、出力 16M chars
> PDF …
