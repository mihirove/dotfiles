---
name: kaizen-ticket-deep-dive
description: Deep-dive a Linear ticket (especially カイゼン / SRE・カイゼン tickets raised by BizOps, CS, AM, Marketing or Corp) BEFORE any fix or code change - reconstruct why it was created, separate the requested solution from the underlying problems and motivations, verify claims against code/data, and propose alternative resolutions including "cancel". Use this whenever the user shares a Linear issue ID or URL (e.g. SKZ-123) and asks to understand, investigate, triage, 深掘り, 整理, or decide whether/how to do it, or says things like "why was this ticket created", "is this still needed", "should I cancel this", "what's the real problem here", "起票の背景", "本当の課題", "代替案" - even if they don't explicitly say "deep dive". Also use before starting implementation on any Kaizen ticket that has not been analyzed yet.
---

# Kaizen Ticket Deep Dive

## Why this skill exists

Most Kaizen tickets are written by BizOps-side people (CS, AM, BizOps, Marketing, Corp). They know the operational pain very well, but the ticket usually arrives already framed as a *solution* ("add a column", "show a popup", "remove this restriction"). The engineer's job on the Kaizen team is not to implement that solution blindly; it's to understand the pain behind it and pick the cheapest change that actually removes that pain — which sometimes means a different change, a non-code change, or cancelling the ticket.

Real example of why this matters: a ticket asked to split the user "start/end date" columns into trial vs. paid. Only in a later comment did the requester write the *most important* reason (「一番の理由」): the ops team could not register the paid start date until the trial had started, and the active-user count shown on screen was misleading. That changes which solutions are viable. The real motivation is often in the comments, a linked Slack thread, or a meeting — not the description.

This skill is **read-only analysis**. Do not edit code, change the ticket's status, or post comments unless the user explicitly asks. The engineer makes the call; the skill gives them what they need to make it well.

## Workflow

### 1. Gather everything about the ticket

First read `references/legalscape-context.md` for which teams use which surfaces.

Use the Linear MCP (load tools with `tool_search` first if they are deferred).

- `get_issue` with `includeRelations: true` (and `includeCustomerNeeds: true`). Note: creator, assignee, status, state history (reopened? bounced between Backlog and Done?), labels, priority, due date, project.
- `list_comments` with `orderBy: createdAt`; **page through all comments** (`cursor`) — the motivation often surfaces late in the thread. Include threaded replies and inline comments (`quotedText`).
- Follow relations one hop: parent, sub-issues (`list_issues` with `parentId`), blocks / blocked by, related, duplicates. Read their descriptions and skim comments — a related ticket may already solve part of the problem, or the ticket may have been spun out of a bigger discussion (look for 「元スレ」「引用元」).
- Follow links in the description/comments: Slack threads (`slack_read_thread`), Notion pages / design docs (`notion-fetch`), GitHub PRs (`pull_request_read`), Google Drive docs. Only follow links that are plausibly relevant; say which ones you could not open.
- Check the **current status of every blocker and related ticket**. A ticket that was blocked months ago may be unblocked now, and that changes the verdict.
- Look for similar past tickets: `list_issues` with `query` using 2–3 key nouns from the title. Search **workspace-wide, not only this project** (older product teams such as `LS-` often hold the original design decisions), and use `includeArchived: true`. Past cancellations and their reasons are gold.
- Read the state history with the comments, not on its own. A jump to Done and back may just be a mislinked PR, not a real completion or reopen. Explain any odd transition from the comments before drawing conclusions from it.

If a tool is not connected or a link can't be opened, keep going and list it under "未確認 / Not checked" rather than stopping.

### 2. Parse the request

BizOps tickets usually follow this template. Extract each section and note which are missing or thin:

| Section | What it tells you |
| -- | -- |
| ビジネス上の目的 | The outcome they want (often closest to the real motivation) |
| 背景 | Current behavior and the pain; history of why the current behavior exists |
| 仮説 | Their causal theory: "if we change X, pain Y goes away" — this is what you test |
| ゴール | Target state |
| 効果 | Claimed impact (e.g. 月10〜15件の問い合わせ削減) — check if it's measured or estimated |
| 希望優先度 / 期限 | Urgency and why |

Engineer-written tickets (背景 / 課題 / 対応内容 style, alert tickets, review-sync tickets) are fine too — adapt, but still separate problem from proposed fix.

**Engineer-written bug / data-fix / follow-up tickets** often have no requester and no stated origin. Before going further, find the incident that started it. Search the 問い合わせ (`OPS-`) team and alert tickets around the creation date, using the ticket's technical nouns and their user-visible symptoms (e.g. `account_organization` → 「ログインできない」「メールアドレス変更」). Tickets created within a day or two of each other are usually the same chain. For these tickets the most useful questions are different:
- Is the priority right, given how often the trigger happens and what the user experiences?
- Should the fix *clean up the data*, *prevent the bad state*, or both?
- What other ticket in the same chain shares the same weak spot?

**Spin-off tickets** ("Phase 2 of SKZ-xxx", a one-line pointer, an empty description) usually carry no motivation of their own. It lives in the parent ticket and its discussion. Treat the parent's description, comments, and linked Slack threads as this ticket's source material. Then check what changed *after* the split: time has passed, and other projects may have moved.

### 3. Separate solution, problem, and motivation

Work out three distinct layers. The report only needs the parts that aren't already obvious from the ticket.

1. **Requested solution** — what the ticket literally asks to build or change.
2. **Problems** — the concrete pains that exist today. Make each one observable: who hits it, when, how often, what it costs (time, errors, customer inquiries, billing mistakes, risk). One ticket often bundles several problems; list them separately because alternatives may solve some but not others.
3. **Motivations** — why solving those problems matters to the requester and the business (ops workload, billing accuracy, customer self-service, contract/legal risk, a deadline driven by a plan launch, etc.).

Ask "why?" of the requested solution until you hit something that is clearly a business pain, but stop there — don't speculate past what the evidence supports. When you infer a motivation that isn't written anywhere, label it as an inference (推測) and turn it into a question for the requester.

Also capture:
- **Why the current behavior exists.** Past restrictions often had a reason (e.g. risk of mis-approval). Check whether that reason still holds — the ticket's 背景 may claim it doesn't; verify.
- **Whether the delivery point still exists.** Look for in-flight initiatives in *other* projects that change the workflow the ticket assumes. For example, a warning in the admin screen is worthless if an automation project removes humans from that step. Search by the workflow's nouns (組織作成, トライアル, 請求 …), not only by the ticket's title.
- **Who agreed to what.** Decisions evolve in comments. Track each stakeholder's stated preference and whether they later agreed to the compromise. Flag any preference that was never re-confirmed (e.g. requester wanted "block", engineer proposed "warn"), because that is where rework comes from.

### 4. Verify claims against reality

Before trusting the premise, check the key factual claims that the solution depends on. Pick the 2–5 claims that matter most; don't try to verify everything.

- **Current behavior**: search the code (`search_code` / `get_file_contents` in `legalscape/wklr-mono` and related repos) to confirm how it works today and where the change would land. If the GitHub connector can't reach the repo (404 or empty search), fall back in this order:
  1. Reuse code findings already written in the ticket's comments (e.g. an earlier investigation comment). Cite them with their date and mark them "not re-checked".
  2. Look at PRs and commits attached to related tickets.
  3. Otherwise, mark the claim ❔ and tell the user which files or functions to check locally or in Claude Code.
- **Frequency / impact**: if a number is claimed, see whether data can confirm it (BigQuery `execute_sql_readonly`, Metabase, Slack channel history). Read-only queries only; keep them small and aggregate.
- **Staleness**: has anything changed since the ticket was written? Recent merged PRs, Done tickets in the same area, a spec change, or BizOps already handling it themselves (a real past cancellation: 「Bizがやってくれたのでcancel」).

Mark each claim ✅ confirmed / ⚠️ partially / ❌ contradicted / ❔ not checked, with the evidence (file path, query, ticket ID, link).

### 5. Evaluate the ticket's solution (the engineer's own judgment)

Steps 1–4 reconstruct what people wrote. This step is where the value is. A report that only restates the ticket isn't enough. Judge the requested solution on two questions, and look for what nobody wrote down.

**a. Is the solution essential (本質的)?**
- Does it remove the cause of the problems from step 3, or only treat a symptom?
- Does it match how the service actually works, or does it add a rule that is convenient for one workflow but false in reality?

A rule that doesn't match reality needs exceptions, and every exception is code someone must maintain and every future feature must respect. Example: org names were made unique although real org names are not unique (same firm name in different regions, several departments of one company). When the solution is not essential, say so plainly, even if the request is reasonable from the requester's side.

**b. Is it appropriate in the short term, the long term, or both?**
A non-essential solution can still be the right call now, when the essential fix isn't available yet and there's no other short-term way. The org-name check was built for exactly that reason. Make the trade-off explicit so the engineer decides deliberately:
- **Essential fix:** what would it be? Search for whether one is already planned or in progress (other projects, design docs); don't assume.
- **Short-term cost:** what does the short-term solution cost to maintain until then — exceptions, extra validation paths, migrations, legitimate cases it blocks?
- **Keeping it removable:** keep it in one place, write down why it exists, and state the condition for removing or relaxing it.

**c. Oversights in the service and operations.**
Walk every workflow that creates, reads, updates or deletes the affected data, not just the screen the ticket mentions:
- create, rename, archive, restore, delete, merge
- bulk operations, scripts, runbooks
- automations and sync jobs
- downstream data and billing
- notifications and customer-facing screens

Also check which **teams** use the affected surfaces (`references/legalscape-context.md`), and whether they would be confused or make mistakes if not told. A correct change that isn't announced can still cause incidents.

Report only real findings, each marked ✅ confirmed or 🔍 to check. Don't write "no impact" rows for every workflow or team.

### 6. Generate alternative resolutions

Always produce a range, not just the requested one. Good alternatives often come from these tiers — consider each, keep only the ones that make sense:

- **Cancel / do nothing** — the problem is already solved, too rare, superseded, or cheaper to tolerate. State what evidence would justify it.
- **Ops / process change** — a different procedure, a checklist, a Slack notification, an existing Claude checker rule, documentation for BizOps.
- **Data / query / report** — a BigQuery view, Metabase question, or one-off data fix instead of a product change.
- **Minimal product change** — copy/label change, a warning, a default value, a validation — smallest change that removes the pain.
- **The requested solution as written.**
- **Structural fix** — the root cause is in the data model or SSoT (e.g. contract dates vs. service periods). Usually bigger; say so, and consider splitting into a quick fix now + a design ticket later.

For each alternative, state:
- which of the listed problems it solves (by number)
- rough effort (S/M/L/XL)
- risk and blast radius — billing, login, and permissions deserve extra care
- reversibility
- whether it is essential, and whether it's a short-term or long-term solution (from step 5)
- which teams need to be told
- what it depends on

Non-essential alternatives are allowed. Label them short-term and give the condition for removing them.

### 7. Recommend, but leave the decision to the engineer

Give one of these verdicts with a short reason:

- **Proceed as requested**
- **Proceed with changed scope** (say what changes)
- **Split** (quick fix now + follow-up)
- **Needs clarification before deciding** (the open questions decide it)
- **Cancel candidate** (with the evidence and a suggested message to the requester)

If the user wrote the ticket themselves, don't address questions back to them. List their own open points as a short checklist, and send the draft comment to the stakeholders who can actually answer (CS for customer impact, BizOps for operating rules). Above the draft, say in one line who each @mention is and why they were picked (e.g. "created the originating OPS ticket"), because they may not be the ticket's creator and the user needs to check the choice.

Then write **questions for the requester**: specific, answerable, and each tied to a decision ("If yes → alternative B is enough"). Avoid generic questions like "What is the purpose?". Draft them as a polite Japanese Linear comment the user can paste (mention the requester with @ if their handle is known), since requesters are Japanese-speaking colleagues.

## Output

Use the structure in `references/report-template.md`. Default the report language to Japanese (the tickets, requesters, and Linear comments are in Japanese) unless the user asks in another language for the report itself — if the user writes to you in English, write the report in English but keep the draft Linear comment in Japanese.

**Keep it short. Don't restate the ticket.** The reader has already read it.
- Write only what is new: findings from comments, links, related tickets, code or data; your evaluation of the solution; oversights; alternatives; questions.
- Refer to the ticket instead of copying it ("P1 = the 背景 in the description").
- Skip any section that has nothing new.
- The TL;DR and the evaluation should fit on one screen.

Cite ticket IDs, file paths, PR numbers, and links so every claim can be checked.

When the user corrects a team detail, suggest adding it to `references/legalscape-context.md`.

## Handling sensitive data

Tickets sometimes contain customer data (org names, OIDs, user emails, contract dates) or internal HR-type information. Only carry into the report what the analysis needs; refer to customers as 組織A / 顧客X where the identity doesn't matter, and never copy lists of personal data into the report or the draft comment.

## Posting to Linear (only after explicit approval)

At the end of every report, offer to post a summary to the ticket. The comment is for the requester and other readers of the ticket, so it should be shorter than the report and written in Japanese:

- 整理した課題（P1, P2…を1行ずつ）
- 検討した対応方針の候補（2〜3案、推奨案があれば明記）
- 起票者への確認事項（番号付き、@メンション付き）

Show the exact comment text first and wait for the user to approve or edit it. Post with `save_comment` only when the user clearly says to post (e.g. 「投稿して」「post it」). Treat "looks good" about the *report* as not approving the *comment*. Never post during testing, dry runs, or when the user said not to — in those cases, show the draft and state that it was not posted. After posting, give the comment link.

Don't put internal-only details in the comment that the requester doesn't need (raw queries, personal data, speculation about individuals). Write inferred motivations as questions, not as facts.

## After the deep dive

If the user decides to proceed, the report's problem list and verified claims become the acceptance criteria — offer to turn them into a short spec or checklist. If they decide to cancel, offer to draft the cancellation comment explaining why and what the requester can do instead (same approval rule as above).
