# Review taxonomy: the 13 categories this team actually comments on

Distilled from `docs/generated/pr-review-observations.md` in wklr-mono (18k human comments on 4.1k merged
PRs, bucketed into these 13 categories), `docs/VIEWPOINT.md` (the anti-pattern table A1–A28 and
per-area notes), bell's `AGENTS.md`, and the mined examples in `examples/`. Frequency order is the
team's, not a textbook's: naming/readability is the single largest bucket, but the *blocking* ones are
further down (security, error handling, tests, dates).

Use the file-type map first, then ask only the questions for the categories that map. The questions are
what reviewers checked; the parenthetical PR numbers are where they checked it, in case you want to read
the original thread.

## File-type → categories to check

| Changed file looks like | Always check | Also check when relevant |
|---|---|---|
| Backend route / controller / service (`wklr-backend-api`, `wklr-admin-api`, `bell-api`, Hono, Express) | 9 security, 6 errors, 5 domain/DB, 8 types | 10 performance (loops with queries), 13 dates |
| DB schema / migration / TypeORM entity / drizzle schema | 5 domain/DB, 8 types | 9 (RLS in bell), 11 docs (migration notes) |
| React component / Remix route / hook | 3 UI/UX, 12 state/async, 1 naming | 7 tests (VRT), 9 (auth guards skipped in DEV), 13 dates shown |
| Job / batch / CLI / crawler | 6 errors, 10 performance, 5 domain | 13 dates (JST boundaries), 2 architecture |
| Test file | 7 tests | 1 naming (test names are spec), 12 (await / flakiness) |
| GitHub workflow / Dockerfile / compose | 4 CI/CD, 9 security (secrets, comment-triggered workflows) | 6 (fail-open steps) |
| Terraform | 4 CI/CD + repo-policies §wklr-terraform | 9 (IAM scope), 11 (why comments) |
| Markdown / design doc / AGENTS.md | 11 docs | 2 architecture (does the doc match the code) |
| Generated (`@gen`, lockfile, snapshot, `dist/`) | nothing inline; mention in summary if suspicious | |

## 1. Naming, readability, code quality (largest bucket)

Raise only when the name or structure would mislead a reader; pure taste is not raised here.

- A name says one thing and the value is another, or two near-synonyms coexist in one context
  (`truthEngineName` / `trueNegative` / `truthNegative`, #8643; `Reference` vs LI's `references`, #8423).
- Domain vocabulary drifts inside one PR (`check` / `detect` / `change`, #8069) or across API, DB and
  code. The team keeps a shared vocabulary; propose the existing term.
- The same responsibility lives in two places (app layer and service layer, #8468, #8069 → A25).
- A function grew past one responsibility; early-return or a helper would cut the nesting. Say this only
  when the PR introduced the growth.
- In bell: 「正本」→「SSoT」, 「管理簿」→「outbox」; comments must be What/Why, never How (bell `AGENTS.md`).

## 2. Architecture and design

- Dependency direction: UI → application → domain → infra. New logic in wklr-mono goes under `packages/`,
  not into legacy roots; new dependencies on legacy need a migration note (VIEWPOINT §3.1).
- bell: `bell-core` must not import `@bell/contract` / DB / HTTP except `persistence/`; orchestration
  lives in `bell-procedure`; persistence is exposed only via `@bell/core/persistence` (barrel pollution
  breaks the SPA with `Buffer is not defined`).
- Long-running counters reset at the right boundary (month/tenant), so one bad period does not cascade
  (#8525).
- A design decision with no written rationale (ADR / design-doc / PR body). Ask for the why rather than
  arguing the choice.

## 3. UI / UX and design-system implementation

- Local CSS, raw color/spacing values where a design-system token exists; token used for the wrong
  purpose (bg token as border, #7121 → A21). Exceptions need a stated reason in the PR (#8001).
- Missing `key` / aria / keyboard handling: treated as a functional requirement, not polish (#6932 → A14).
- Generic error text (「エラーが発生しました」) where the user needs to know what happened (#6934 → A15).
- Re-implemented component or translation key when an existing one fits (#8274).
- Display reads as wrong for some state (a "current" vs "after approval" pair that misreads once the
  request is processed, #8876). Walk every status the screen can show.
- bell UI copy rules: 句点 by sentence ending, 「〈対象〉はまだありません。」 for empty states, copy fixed
  by component tests with anchored regex.
- UI change without VRT baseline update, or with an unexplained VRT diff.

## 4. CI/CD, build, dependencies, environment

- New workflow job without `timeout-minutes` (bell: all jobs 10 min); duplicate step ids (#8774);
  `curl` with no timeout; stale checks that only look one direction (fail-open).
- Caches that could contain credentials (`auth.json`, API keys) (#7766); secrets added to GitHub Secrets
  where Secret Manager is the convention (#8376).
- A concurrency / rollout fix applied to one service that every sibling needs (#8642).
- Flaky test "fixed" by retry rather than root cause (#6913 line).
- Docker / Node / pnpm pins drifting between local, CI and prod.

## 5. Domain logic, data integrity, search / DB

- New column types that do not match the referenced column (`BIGINT UNSIGNED`), missing column
  COMMENT, `NOT NULL` where the source can be NULL (#8667).
- Sort comparators that never return 0 or sort on one key: pagination duplicates/gaps (#6887 → A4).
- `DISTINCT` where the business needs "latest by version/flag" (#8469).
- Identifier semantics mixed (`revision_id` vs `natural_id` in the same payload, #8291).
- Migration without forward *and* backward check; Docker volume / existing data impact not in PR body.
- bell: any new table in `tenant` schema must be covered by RLS and the coverage harness; ENUM parity
  between zod and Postgres; transaction boundary has a rollback test.

## 6. Error handling, validation, robustness

- Swallowed exceptions: `catch {}`; `catch` that returns a default without logging (#7008, #7774 → A1).
  bell: log the original error *where it is flattened*, chain `cause`, structured JSON, no secrets.
- Boundary validation missing on request params / headers → 500 instead of 400 (#6698 → A12). Prefer
  OpenAPI / zod at the edge over hand-rolled checks in the service, when the check needs no DB (#8833).
- Fail-open branches on timeout / budget exceeded / missing digest (#8428, #8660). Ask which of
  fail-open / fail-closed / fail-fast is intended and whether 429/503 bypass audit logging.
- Rate-limit response added server-side without the client that reads it (#8660).
- Retry strategy stated as "exponential backoff" without saying which errors retry.
- Status codes multiplexed: "not found" and "not allowed" both 403 force callers to parse bodies (A26).

## 7. Tests and coverage

- Behavior changed, no test changed. On bell this is *the* review: reviewers read tests only, so an
  untested behavior does not exist; a test that asserts visibility but not the exact copy is incomplete.
- Feature flag tested on one side only (#7069 → A16).
- Mock diverging from implementation; DB logic tested with in-memory stand-ins instead of the test DB
  (#8069 → A17).
- E2E that proves presence with `toHaveCount(0)` or text that also exists elsewhere: passes when the
  route is broken (#8770, #8782).
- Test placed in the wrong layer: an E2E for a string comparison the service test already covers (#8832);
  bell has an explicit component/ vs ui/ split.
- DB verified directly where the repo's `AGENTS.md` says to wait for the success response: fine as an
  intentional exception, but the exception must be written down next to the assertion (#8832).
- Missing routing/regression test when a new type joins an existing switch (#8292).

## 8. Types and schema design

- `any` / `unknown` at a boundary without validation (#6671 → A10); bell forbids `as` entirely.
- TypeScript type and DB/OpenAPI schema maintained twice (A11); snapshot types that are partial copies
  of a bigger type without validation (#8240).
- Nullability: DB nullable + TS union that is never checked at runtime.
- Generated OpenAPI enums changed by hand instead of regenerating.

## 9. Security, authentication, authorization (blocking)

- Fail-open guards: unset role requirement → allow (#6978 → A2); eligibility that checks the org but not
  the user's `validFrom/validUntil` (#8359).
- Trusting IAP-set headers on a path that can be reached without IAP (`.run.app`, `X-Serverless-Authorization`)
  (#8669).
- IDOR: external id used to load a resource without ownership check (#6436 → A22).
- PII or tokens in logs / error responses / analytics (#7356, #8360).
- Unauthenticated endpoint returning more than "observably public" data; the qualitative reason must be
  in a comment (#8423). `/public/` prefix means CDN-cached, not unauthenticated.
- Client-supplied times accepted without server re-validation (#6880 → A5).
- Comment-triggered workflows guarded only by `user.type != Bot` (#8779): require `author_association`.
- Returning a URL after `new URL()` validation using the raw value (control chars survive).
- bell: RLS tenant context is `SET LOCAL app.tenant_id`; unset must yield 0 rows (fail-closed).

## 10. Performance

- N+1: query inside a loop, lazy relations in a list (#7356, #6581 → A3). Ask for before/after counts in
  the PR body.
- `useEffect` used to derive state that could be computed during render (#6083 → A6).
- Batch size / concurrency hard-coded instead of env-configurable; connection limits for high-fanout
  jobs (#6913).

## 11. Documentation, PR process, communication

- PR body lacks the *why* (#7266 → A20) or the rollback / rollout note for migrations and infra.
- wklr-mono `REVIEW.md`: a change to commands, structure, env vars, security or ops without the matching
  `AGENTS.md` / `ARCHITECTURE.md` / `docs/*.md` update is a finding; `CLAUDE.md` must mirror `AGENTS.md`.
- A domain decision (why this default, why this exception) not left as a code comment (#8270 → A23).
- Design docs using jargon (ZDR profile, DPA) without a gloss (#8521 → A28).
- bell PR body: 「追加 / 変更したテストケース」 and QA checklist exclusions are mandatory, in Japanese.
- Screenshot / diagram missing for a UI or architecture change (#8732).

## 12. State management and async

- `setState` based on stale closure instead of an updater (#7063, #6959 → A7).
- Zustand slices writable across boundaries (#6770 → A9).
- Missing `await` (also in tests) that only shows in dev (#6991 → A8).
- Side effects on a FAILED subscription / already-terminal state (#7946).

## 13. Time zones, dates, i18n

- JST/UTC mix-ups; persisted in UTC, converted only for display (#4826 → A13); fallbacks like
  `new Date()` leaking into display (#8284).
- Date boundaries (month/day) computed in the wrong zone; past/future dates changing notification
  behavior (#4812).
- Translation keys invented when a shared one exists.

## PR-level checks (run once per PR, after the hunks)

1. Title and body in Japanese where the repo requires it (bell: always; wklr-mono: template sections
   実装方針 / 関連リンク / 相談 / チェックリスト).
2. Body explains why, states test evidence, and (for migrations/infra) rollback.
3. Docs updated per `REVIEW.md` / `AGENTS.md` rules; `CLAUDE.md` still a symlink or mirror.
4. Every behavior change has a test; flags tested both ways; VRT noted.
5. Nothing generated was edited by hand; lockfile changes match `package.json` changes.
6. Secrets / PII / credentials nowhere in the diff, fixtures, or CI cache paths.
7. For terraform: plan output or Atlantis status referenced; `_common` changes gated per env; no state
   surgery.
