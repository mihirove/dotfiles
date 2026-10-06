# Repo policies: where the rules live and what counts as blocking

Each section says what to read in the checkout, what reviewers there treat as blocking, and the traps
that produce false positives. For a legalscape repo not listed here, use the wklr-mono section and say
in the summary that the repo had no specific policy loaded.

## legalscape/wklr-mono (monorepo: iris, wklr-backend-api, wklr-admin, wandh, ccc-*, ...)

**Read**: `/AGENTS.md` (entry point), `/REVIEW.md` (review rules + security checklist + the strict
"docs updated?" rule), `/docs/VIEWPOINT.md` (per-area viewpoints, anti-pattern table A1–A28, security and
performance specifics), and the `AGENTS.md` of every changed package (`packages/<pkg>/AGENTS.md`,
`wklr-backend-api/AGENTS.md`, `wandh/AGENTS.md`, `datamodel/AGENTS.md`). The PR template is
`.github/PULL_REQUEST_TEMPLATE.md` (実装方針 / 関連リンク / 相談 / チェックリスト).

**Language**: review comments in Japanese (REVIEW.md, first line).

**Blocking by team history**: fail-open authorization (A2), IDOR (A22), PII/tokens in logs or responses,
swallowed exceptions in jobs (A1), JST/UTC errors (A13), feature flag tested on one side (A16),
migration without rollback note, `AGENTS.md` not updated when REVIEW.md says it must be.

**Should-fix**: misleading names and vocabulary drift (#1 bucket), N+1, `useEffect`-derived state,
design-system token misuse, generic error messages, missing aria/keyboard.

**Traps**:
- `/public/` is a CDN-cache prefix, not "unauthenticated"; auth is decided by `x-ls-endpoint-skip-auth`.
- `SKIP_AUTH=true` and `import.meta.env.DEV` disable guards locally; "works locally" proves nothing
  about auth. Ask for dev-environment verification, not a local screenshot.
- `csrfHeaderCheck` requires `x-requested-with` on GET too; server-to-server callers forget it.
- Generated API clients live under `packages/@gen/`; hand edits there are a finding, diffs there
  otherwise are noise.
- Free plan is pre-GA; anything touching `organization.config.isFree` must respect
  `docs/product-specs/free-plan-release-boundary.md`.
- Bots already present: Greptile (Japanese, strictness 3), Codex AI PR review (`ai-pr-review.yml`,
  sticky comment, opinion approve/pending/need-fix), Codex security review, Copilot, Dependabot
  reviewer. Read their comments before writing yours; duplicate = skip.
- Many human-account comments carry a Claude Code footer. They are still the team's accepted review
  practice; weight hand-written ones for *tone*, all of them for *substance*.

## legalscape/bell (LS3.0: bell-core / contract / db / procedure / api / web / login, doyle in Python)

**Read**: `/AGENTS.md` (long; the sections レビュー方針, テスト戦略, エラーハンドリング, UI 文言, TypeScript,
bell-core, DB スキーマ, 永続化アーキテクチャ are all review criteria), `.claude/skills/qa-test-design/SKILL.md`
(JSTQB-based checklist the QA bot grades against), `docs/qa-carryover/` (open test debt the PR should
have picked up if it touched that area), `docs/error-handling.md`, `docs/data-model.md`. PR template:
`.github/PULL_REQUEST_TEMPLATE.md` (概要 / 追加・変更したテストケース / QA 観点チェックリスト / VRT /
デプロイ時のサービス影響).

**Language**: PR title, body, commits and review comments in Japanese.

**The one rule that reorders everything**: reviewers read *test cases only*. A behavior without a test
does not exist; a test without a behavior is an acceptable TDD state. So for application code
(`packages/*/src/**`, `doyle/packages/*`, `contracts/`, bell-db schema+migrations) your first pass is
over the test diff: does every changed behavior in `src` have a case; are rejection paths and
boundaries present (§4 of the QA skill); is there a rollback case for multi-step writes; are RLS
tenant-isolation and fail-closed cases present for new `tenant` tables; are UI strings fixed with
anchored regex; are LLM-nondeterministic tests limited to 3 attempts with the mandated failure message.
Implementation-code findings are secondary and should be phrased as "the tests do not pin this".

**Out of scope for the test rule**: `terraform/**`, `compose*.yaml`, `dockerfiles/`, workflows, tool
configs, `scripts/`, Auth0 custom DB scripts. There, review the definition file itself; the PR body must
say 「対象外（アプリケーションコードの変更なし）」.

**Blocking by team history**: type assertions (`as`) in TS; `catch {}` without logging; external data not
parsed with zod; new `tenant` table without RLS coverage; `K_SERVICE`-based runtime detection replaced
by ad-hoc env flags; How-comments; 「正本」/「管理簿」 wording; UI copy without a test; QA verdict
`blocker` (implementation exists but no test).

**Traps**:
- Tests must *fail* when Postgres/Redis is missing; a `describe.runIf` skip is a finding, not a nicety.
- `test.fixme` is the sanctioned way to declare a viewpoint that cannot be observed yet; do not ask for
  it to be implemented in the same PR.
- Component tests do not fix pixel values; VRT does. Do not ask for px assertions.
- Evidence helpers `evidenceGiven/When/Then` ordering and `acceptanceCriteria(...)` IDs are checked by
  `test/e2e-evidence.test.ts`; an unknown AC id fails CI, mention it before CI does.
- Prompt wording for the LLM is reviewed by reading the diff, not by tests (golden digest only).
- The QA review bot posts `qa-review/verdict`; if its comment exists, do not restate its checklist.

## legalscape/wklr-terraform (GCP infra for wklr; Atlantis apply-before-merge)

**Read**: `/README.md` (directory conventions: `modules/` generic, `components/<app>/{_common,dev,stage,prod}`;
version pinning via `required_version` only, no `.terraform-version`), `.claude/skills/lb-prod-bg-deploy/SKILL.md`
when `load_balancing` or prod LB/url_map/backend is touched, `docs/` for SLO and architecture diagrams,
and wklr-mono `docs/VIEWPOINT.md` §1.7 (the Atlantis traps are written there).

**Language**: Japanese.

**Blocking by team history**: a prod change that edits the live (blue) side instead of the standby when
the Blue/Green procedure applies; IAM grants broader than the stated need (`roles/*.admin` where a
narrower role exists, project-level where resource-level works); `_common` changes without an
`enable_*` gate when only one env should take them; data sources that will not exist in `canary`;
secrets or keys in `.tf` or `files/`; `terraform state rm` / `-target` suggested as a fix.

**Should-fix**: missing Why comment on a non-obvious resource (ForceNew constraints, external SSoT,
why a resource is absent); duplicated variables across envs that should live in `_common`;
`sku_check.sh` not mentioned for Azure OpenAI deployment changes; monitoring/alert policies without
the fields on-call needs (job name, requestId, URL — #1151, #1167).

**Traps**:
- A destroy in the plan may come from someone else's applied-but-unmerged PR on the same component;
  ask about open PRs before calling it a bug.
- Comments that restate the resource type or the ternary are *removed* on this team (bell comment
  rules apply here too); do not ask for more of them.
- There is no test suite; the diff and the plan are the review surface. Ask for the plan summary when
  the PR body lacks it.
