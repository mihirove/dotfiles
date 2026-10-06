# Comment style: how this team writes review comments

Measured on hand-written inline comments from recent merged wklr-mono PRs (124 threads): median length
92 characters, 90th percentile ~1000; about half are phrased as a question or a soft proposal
(「〜でしょうか？」「〜の方が良さそう」「〜気がしました」), 15% as a directive (「〜してください」);
authors push back on roughly a third and reviewers accept it. Severity is signalled with a short
bracket prefix, not with emoji or ALL CAPS. Reviews are submitted as COMMENT or APPROVED with the
nits attached; "request changes" is rare. Everything is in Japanese.

Write like a colleague who read the code carefully and is asking, not like a linter that is sure.

## Severity vocabulary (use exactly these prefixes)

| Prefix | Meaning on this team | When |
|---|---|---|
| `【要対応】` | should be fixed before merge; reviewer would not approve as is | real bug, fail-open auth, PII leak, missing test for changed behavior, broken contract |
| `【提案】` | should-fix; author may decline with a reason | misleading name, duplicated responsibility, N+1, missing Why comment, docs not updated |
| `【任意】` or `nits:` | take it or leave it; never blocks | wording, minor structure, a nicer API |
| `【質問】` or `[ask]` | you do not understand the intent or could not verify | anything you could not confirm in the code |

Hand-written reviewers also mix forms (`[ask][nits]`, 「nit（感想レベル）」). Pick one prefix per
comment; put the strongest first when a comment has two parts.

## Shape of one inline comment

1. **Prefix + one-sentence claim** that a skimming author can act on.
2. **Evidence**: what in the code makes it true, with line references in the `L80–90` style the team
   uses, and the concrete consequence for a user or operator (「原文後半が訳されていないことが利用者に
   伝わりません」 beats 「不正確です」).
3. **Proposal**: the smallest change that resolves it, or the question that would. A
   ```` ```suggestion ```` block is fine for one-line fixes; do not use it for anything larger.
4. Nothing else. No restating the diff, no praise padding, no "consider adding a comment" without
   saying what the comment should say.

Keep 【任意】 comments to one or two sentences. Keep 【要対応】 comments complete even if long: the long
hand-written comments in the corpus are all 要対応-class, and they are long because they trace the
exact path (which line sets what, which state is missed).

### Examples lifted from the corpus (hand-written)

> `exchangeCustomTokenForIdToken` はリクエスト body に `{ token: customToken, ... }` を含むそうなので、
> error を丸ごと log するのはやめたほうが良さそうですかね？

Short, soft, specific, and the author fixed it in the next commit. This is the default register.

> L80–90 では本文が空かどうかだけを確認し、L99 で成功を返しているため、finishReason=MAX_TOKENS などで
> 途中までの本文が返った場合も完成した訳文として扱われます。空でない未完の訳文は iris 側でも成功結果と
> して表示・キャッシュされ、原文後半が訳されていないことが利用者に伝わりません。finishReason が正常終了を
> 示すことも検証し、途中終了は翻訳失敗として扱うのがよさそうです。

Claim → mechanism with line refs → user impact → smallest fix. This is the 要対応 register.

> [ask] publication_period_invalid_range って article のみに絞る必要がありますか？

When you are not sure the author is wrong, ask. Half the corpus is this.

### What the team does *not* write

- Comments on generated files, lockfiles, or formatting the linter owns.
- "Consider extracting this into a helper" with no misreading or duplication to point at.
- Security boilerplate that does not apply to the hunk (no "validate all inputs" on a test file).
- Repeating what a bot already said. If Greptile / Codex / the QA agent already raised it, skip or
  add only new evidence as a reply.
- English. Even when the code and identifiers are English, the prose is Japanese.

## Review summary (the top-level body)

Three short parts, in this order, Japanese, no headers larger than `###`:

```
### 概要
<1–3 sentences: what the PR does and the overall risk level you see>

### 指摘（インライン N 件）
- 【要対応】<path>:<line> — <one line>
- 【提案】<path>:<line> — <one line>
（インラインに付けた指摘の索引。本文はインライン側）

### 任意・確認できなかったこと
- <任意 items that did not deserve an inline comment, one line each>
- <what you could not verify: no local checkout / dev-only behavior / plan output not in PR>
```

If there are no inline findings, say so plainly (「インラインの指摘はありません」) and still fill the
third section; an empty review is less useful than "I checked X, Y, Z and found nothing".

When reviewing your own freshly created PR, write the summary in first person about what you will fix
(「〜は次の commit で直します」) and update it after pushing.

## review.json shape expected by `scripts/post_review.sh`

```json
{
  "summary": "### 概要\n…",
  "comments": [
    {"path": "packages/iris/app/routes/x.tsx", "line": 87, "body": "【要対応】…"}
  ]
}
```

`line` is the line number on the new side of the diff. Lines that are context-only or outside the
diff will be rejected by GitHub; the script folds those into the summary automatically, but prefer
anchoring on a changed line in the first place.
