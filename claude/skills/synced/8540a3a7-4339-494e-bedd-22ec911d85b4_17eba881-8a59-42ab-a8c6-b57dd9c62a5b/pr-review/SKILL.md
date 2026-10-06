---
name: "pr-review"
description: 'Review a GitHub pull request the way the Legalscape team actually reviews, learned from thousands of human review comments on merged PRs in wklr-mono, bell and wklr-terraform. Use this whenever a PR was just created or pushed in the session (run it right after `gh pr create`, `/draft`, or `/pull-request` finishes, without being asked), whenever the user says "review this PR", "レビューして", "PR 見て", "セルフレビュー", "review #1234", pastes a PR URL, or asks what a reviewer would say about their branch. It fetches the diff and existing comments, walks the team''s 13 review categories, calibrates each finding against real past comments, and posts Japanese inline comments plus a summary as a COMMENT review (never approve / request changes). Prefer this over generic code-review for any legalscape/* repository. Also handles "retrain" / "update review examples from merged PRs".'
compatibility: Needs `gh` (authenticated) or ambient GitHub REST credentials, `git`, and `python3`. Posting requires pull-request write access.
---

# PR review, the way this team does it

You are about to review a pull request as a Legalscape colleague would. Everything in `references/`
was distilled from real review threads on merged PRs: what reviewers raised, what they let pass, how
they phrased it, and how authors responded. Treat those files as your supervision signal: a finding is
worth posting when a past reviewer on this team would plausibly have raised it, in the way they
would have raised it.

Two things matter more than volume. **Precision**: one wrong or trivial comment costs more trust than
three missed nits, and this team already runs several bot reviewers (Greptile, Codex, Copilot, the
repo's own QA agent), so noise is the failure mode, not silence. **Calibration**: say how sure you are
and how much it matters, in the team's own vocabulary (blocking / should-fix / 任意・提案 / 質問).

## Workflow

### 0. Resolve the target

| Input | Target |
|---|---|
| `#123`, `123`, a PR URL | that PR |
| nothing, and a PR was created or pushed earlier in this conversation | that PR |
| nothing, inside a repo checkout | the open PR for the current branch (`gh pr view --json number`, or `curl https://api.github.com/repos/<owner>/<repo>/pulls?head=<owner>:<branch>` when `gh` is not authenticated); if none, review `git diff <default>...HEAD` as an unposted dry run |
| `--dry-run` anywhere | produce the report but post nothing |
| `retrain` / `update examples` | skip to §Retraining |

### 1. Fetch the PR bundle

```bash
bash <skill>/scripts/fetch_pr_context.sh <owner/repo> <number> <out-dir>
```

It writes `meta.json`, `diff.patch`, `files.json`, `existing_comments.json` (inline + conversation +
review summaries, humans and bots alike), `review_threads.json` (resolved / outdated flags) and
`checks.json`. Read `meta.json` and `existing_comments.json` first, then the diff.

If the repository is checked out locally, also run `git diff <base>...<head> --stat` to confirm the
patch matches what you fetched; a stale fetch means commenting on lines that moved.

With no PR (branch dry run) there is nothing to fetch: use `git diff <base>...<branch>` for the patch,
`git diff --name-only` for the file list, and `git show <branch>:<path>` to read surrounding code
without switching branches. Line numbers for findings are still new-side numbers from the patch.

### 2. Load the rules that reviewers hold authors to

Read, in this order, skipping what does not exist:

1. `references/repo-policies.md` → the section for this repo. It tells you where the written rules
   live, what the team treats as blocking, and the repo-specific blind spots.
2. In the checkout (or via `gh api .../contents/`): root `AGENTS.md` / `CLAUDE.md`, `REVIEW.md`,
   `docs/VIEWPOINT.md`, and any `AGENTS.md` in the parent directories of changed files. Nested
   agent docs often hold the exact rule a reviewer will cite.
3. `references/review-taxonomy.md` → the 13 categories with concrete checks. Keep it open.
4. `references/examples/<repo>.md` → real hunk → comment pairs for this repo (fall back to
   `wklr-mono.md` for an unknown legalscape repo). Skim the whole file once; you are learning what
   gets raised *and* the tone, not searching for a match.
5. `references/comment-style.md` → phrasing, severity markers, and the comment template.

### 3. Review pass

Walk the diff file by file, hunk by hunk. For each hunk ask the taxonomy questions that apply to that
kind of file (the taxonomy maps file types to categories). Keep a scratch list of candidate findings
with: path, line (new-side line number from the patch), category, severity, one-line claim, and the
evidence (what in the code makes it true).

Then, for every candidate, do the calibration step that makes this skill different from a generic
reviewer:

- **Would this team raise it?** Find the nearest past example in `examples/<repo>.md`. If reviewers
  historically let this kind of thing pass (style preferences the linter already covers, speculative
  refactors, "consider adding a comment" with no concrete risk), drop it or fold it into the summary
  as a one-line 任意. The reverse matters just as much: the single biggest bucket of real comments
  here is *placement and shape*, and those are easy to under-report when you are hunting for bugs.
  Reviewers on this team reliably say something when a new helper lands in a file whose name does
  not cover it (CPU-count logic inside `gcv.ts`), when a hand-rolled branch reimplements what the
  platform already provides (a cgroup reader where `os.availableParallelism()` suffices), when the
  same thing already exists in a sibling package, or when a parameter's edge cases (fewer items than
  workers) are not discussed. Raise those as 【提案】 or 【質問】 even when the code is correct; they are
  what makes the review read like a colleague's rather than a scanner's.
- **Is it already said?** Compare against `existing_comments.json`. Anything a human or bot already
  raised on the same lines is skipped; if you have genuinely new evidence for an open thread, reply
  there instead of opening a new one.
- **Is it true?** Open the surrounding code (not just the hunk) before claiming a bug. When a checkout
  and a cheap way to execute exist (a pure function you can call, a single test file you can run),
  do it: "verified locally: `price_for('x@default')` returns the Opus row" turns a guess into a fact
  and is the kind of evidence this team trusts. If you cannot verify (no checkout, generated code,
  prod-only behavior), phrase it as a question and say what you could not check.
- **Does it matter?** Severity follows the team's history, not textbook severity. In this org, fail-open
  authorization, PII in logs, missing tests for changed behavior, and JST/UTC mistakes are blocking;
  naming and structure are should-fix when they mislead, 任意 otherwise.

Finish with the whole-PR checks that have nothing to do with a single hunk (the taxonomy's §"PR-level"):
description explains *why*, docs updated where the repo requires it (wklr-mono's `REVIEW.md` is
strict about `AGENTS.md`), tests cover both sides of a flag, VRT/baseline notes, migration and
rollout notes, and for bell: every behavioral change has a test case, because reviewers there read
tests only.

Aim for the handful of findings that matter. A typical reviewed PR on this team gets 2–6 inline
comments; more than ~10 means you are not calibrating. A good mix for a mid-size code PR is one or
two correctness / robustness points, one or two placement / naming / simplification points, and one
question about an assumption you could not verify. If a file is generated (`@gen`, lockfiles,
snapshots), say so and skip it.

### 4. Write the report

Always write the report first, to `<out-dir>/review.md`, in Japanese, using the template in
`references/comment-style.md`. It has three parts: a one-paragraph summary (what the PR does, overall
risk, what you did not check), the inline findings (each with severity, claim, evidence, proposal),
and 任意 notes folded into a short list. Show the report to the user in the conversation as well.

### 5. Post

Unless `--dry-run`: post with

```bash
bash <skill>/scripts/post_review.sh <owner/repo> <number> <out-dir>/review.json
```

The script checks every comment's new-side line against the PR's patch first, folds any comment whose
line is not in the diff into the summary, then submits everything as one review with event `COMMENT`.
If that submit still fails, it posts a summary-only review carrying every finding, so nothing is lost.
It never approves or requests changes; whether the PR is mergeable is a human's call and the team gates
that with rulesets. Add `--dry-run` as the fourth argument to see how many comments would go inline
without posting. No footer is added by default; set `PR_REVIEW_FOOTER` if you want one appended.

If you reviewed a dry-run diff with no PR, there is nothing to post; the report is the deliverable.

### Claude Code on the web

`gh` is usually not authenticated there. `fetch_pr_context.sh` and `post_review.sh` both fall back to
`curl` with the credentials the environment injects at the proxy, so run them as usual. GraphQL is
blocked, which is why only REST routes are used. If posting still fails (for example the injected
token lacks pull-request write access), the script exits with code 3 and `review.md` is the deliverable.

## When the PR is already merged

Say so in the first line and frame findings as follow-ups (「merge 後の追従提案として」). Do not
re-litigate threads that were settled with an approval; a new finding on the same lines is fine if it
adds evidence the thread did not have.

## When you are reviewing your own PR

Right after creating a PR, you usually are. That is fine and expected on this team (many threads in the
examples are authors self-reviewing with Claude). Two adjustments: write findings as things *you* will
fix, not requests to the author, and follow through: if a finding is a clear bug in your own change,
fix it, push, and mention the commit in the comment instead of leaving a to-do for a human.

## Retraining

The examples are a snapshot. To refresh them from newly merged PRs:

```bash
python3 <skill>/scripts/mine_review_examples.py legalscape/<repo> --max-prs 150 --out /tmp/mined.jsonl
python3 <skill>/scripts/distill_examples.py /tmp/mined.jsonl --out <skill>/references/examples/<repo>.md
```

The miner keeps only human review threads (drops the author, bots, Linear/CI automation, bare approvals)
and tags comments that carry an AI-assistant footer so hand-written ones can be weighted for style.
`distill_examples.py` buckets threads into the 13 categories by keyword, trims hunks, and writes the
markdown the skill reads. Review the output before replacing the old file; keep each file around 1000 lines or less by
lowering `--max-per-category` rather than by dropping whole categories.

## Files

- `references/review-taxonomy.md` — the 13 categories, concrete checks per category, and the file-type → category map
- `references/repo-policies.md` — per-repo: where the rules live, what is blocking, known traps
- `references/comment-style.md` — phrasing, severity vocabulary, report and comment templates
- `references/examples/{wklr-mono,bell,wklr-terraform}.md` — mined hunk → comment pairs with author responses
- `scripts/fetch_pr_context.sh` — one-shot PR bundle (REST only; GraphQL is blocked in Claude Code sessions)
- `scripts/post_review.sh` — validates lines against the patch, then submits one COMMENT review (summary-only fallback)
- `scripts/mine_review_examples.py`, `scripts/distill_examples.py` — retraining pipeline
- `assets/hook-settings.json` — optional user-level hook that nudges this skill after `gh pr create`
