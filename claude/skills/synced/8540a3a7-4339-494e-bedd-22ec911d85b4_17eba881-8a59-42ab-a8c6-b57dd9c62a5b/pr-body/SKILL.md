---
name: pr-body
description: "Rules and procedure for writing or rewriting a pull request body. Use when creating the body for a new PR,\nwhen cleaning up, refactoring or updating an existing PR body, or when asked things like\n\"fix the PR body\", \"write the PR description\", \"PR 本文を直して\", \"PR の説明を書いて\".\nDoes not cover creating, pushing or labeling the PR itself (leave that to the draft / pull-request skills or the git-draft agent).\nThe skill's instructions are in English, but the PR body itself is always written in Japanese.\n"
---

# PR body

A PR body holds only what the diff, CI and the GitHub UI can't show:
why the PR is needed, where the change sits in the overall system, what was decided and why, and what the reader needs to decide.

**Write the PR body in Japanese.** These instructions are in English, but every word that goes into the body
(headings, sentences, diagram labels) is Japanese, following the style rules below.

## Required: reread the latest body right before every update

When updating an existing PR body, fetch the current body **immediately before every write**
(`pull_request_read` with `get`, or `gh pr view <n> --json body`).

- Never build from a body you read earlier in the conversation or from your own previous version. The user or reviewers may have edited it on GitHub
- Compare the fetched body with your draft and keep anything the user added or changed. Ask before removing it
- After updating, fetch the body again and confirm it came out as intended (Markdown, bot blocks, the mermaid code block)

## What not to write

| Don't write | Why |
|---|---|
| Verification (commands and results, test counts) | Visible in the CI results |
| A file-by-file list of changes | Visible in the "Files changed" tab |
| A PR-stack diagram or merge order | GitHub's stacked PRs feature shows it. Put related PRs under 関連リンク instead |
| Fixes made along the way, or the work history | The body describes the current state only. History goes in PR comments |
| Empty content such as 「相談: なし」 | Delete the whole section instead |

Use a table only when a table is what shows a decision (for example, what serves `/api` in production vs. development, or how tsconfig is split).

## Structure

Keep the headings and order of the repository's PR template (`.github/PULL_REQUEST_TEMPLATE.md`).
**Never put text outside a section** (for example, above the first heading). Remove the template's `<!-- -->` comments.

For wklr-mono, use this shape:

````markdown
## 実装方針のトピック

<Why this PR is needed, in 2–4 sentences: project or ticket background → what is missing today → what this PR does>

オレンジの箇所が対象

```mermaid
flowchart LR
  ...(show where this PR sits within the overall system)
  style <parts this PR adds or changes> fill:#ffeacc,stroke:#f90,stroke-width:2px;
  style <follow-up tickets> fill:#eef0f2,stroke:#9aa0a6,stroke-dasharray:4;
```

### ⚠️ <anything that blocks merge or CI, if any>

<What happens, why, and when it gets resolved>

### <heading that states the decision, e.g. 「React は 18 にした」>

<The reason, plus rejected alternatives if any>

### <decision 2>

...

## 関連リンク

- <ticket>
- <related PRs, including the base PR>
- <design docs>

## 相談

- <a concrete question the reader can answer, ending in 「〜か。」>

## チェックリスト

- [x] ...
````

### Diagram

- Use a `flowchart` (structure or data flow) or a `sequenceDiagram` (order of processing). Never a PR-stack diagram
- Color what this PR adds or changes orange (`fill:#ffeacc,stroke:#f90,stroke-width:2px`) and put 「オレンジの箇所が対象」 right before the diagram
- Leave existing parts in the default color; draw follow-up tickets as grey dashed boxes
- Quote labels containing `/` or `(` with `"..."`. Use `<br/>` for line breaks
- Render the diagram before posting to check the syntax (for example `npx -y @mermaid-js/mermaid-cli@11 -i d.mmd -o d.png -p cfg.json`,
  where `cfg.json` is `{"args":["--no-sandbox"],"executablePath":"/opt/pw-browsers/chromium"}`)

### Decision sections

- The heading states the decision itself (never 「詳細」 or 「備考」). Skimming the headings alone should give the list of decisions
- One decision per section. The body gives the reason (ending in 「〜ため。」) and, if relevant, rejected alternatives
- Order sections by importance

## Style of the Japanese text

- Plain form (常体: 「〜する」「〜した」「〜のため」), not です・ます
- Wrap code, paths, commands, environment variables and package names in `` ` ``
- Bold only the one sentence a reviewer must not miss
- Never include secrets (tokens, keys, internal credentials)

## Bot blocks and footers

- Copy blocks that bots add to the body (for example `<!-- codesmith:footer -->` … `<!-- /codesmith:footer -->`) unchanged from the freshly fetched body
- The GitHub MCP `update_pull_request` tool can rewrite `<source>` / `<img>` tags. If a bot block comes back broken after the update,
  remove the whole block (the bot adds it again on its next update). Never leave it broken
- Keep `🤖 Generated with ...` and the session URL. If they appear twice, keep one

## Checklist before posting

- [ ] Fetched the latest body right before writing and kept the user's edits
- [ ] No text outside a section
- [ ] The opening says why the PR is needed
- [ ] There is a diagram with this PR's parts in orange (for PRs that change structure or flow)
- [ ] No verification, file list, or stack diagram
- [ ] Every decision section gives a reason
- [ ] Every 相談 item is a concrete question
- [ ] Reread the body after updating and confirmed nothing is broken
