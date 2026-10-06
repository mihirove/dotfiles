# Who uses which surface

Use this to check which teams a change affects. Anything not listed here is a question, not a guess. Update this file when the engineer corrects something. Sources are noted so each line can be re-checked.

## Engineering teams (プロダクト開発本部)

| Team | Responsible for | Relation to the internal admin screen |
| -- | -- | -- |
| **SV — ソリューションバリュー** | The customer-facing product: the web app (iris), Watson & Holmes, Legal Intelligence integration, PLG and billing models, auth and the backend API. Also handles production alerts for these services. | Has built product-side features in the internal admin screen: simple IAM, org feature flags, pack creation, physical user deletion, LI integration settings, ZDR settings. Coordinate with SV when a Kaizen change touches these, or touches auth/login. |
| **CV — コンテンツバリュー** | Legal content data (books, statutes, case law): the structuring pipeline, CCC tools (ccc.ops.legalscape.jp), contents-api, revisions. | **Builds the document (文献) features:** registration, bibliographic data, publishing. These are moving out of the internal admin screen into ccc-admin-ui (for example, the article screens). Check which screens are still in the internal admin screen. |
| **SRE** (part of the SRE・カイゼン Linear team, but a separate responsibility) | Reliability of the platform: infrastructure (GCP, Terraform in wklr-terraform), monitoring and alerts, and reliability work in coordination with SV. 🔍 Confirm the exact scope with the engineer. | Not a business user of the admin screen. Involve SRE when a change touches infrastructure, IAM, deploys, scheduled jobs, or monitoring. |
| **カイゼン** (part of the SRE・カイゼン Linear team; this skill's user) | **Owns the business-operation workflows:** the trial process, organization creation, enrollment (本利用登録), and user creation, plus related flows seen in its tickets: customer requests and approvals (申請), account replacement, account-management Slack notifications, and account/billing sync jobs. Also handles BizOps / CE / CS improvement requests and OPS tickets. | **Owns these workflows in the internal admin screen** and the APIs and jobs behind them. A change here is Kaizen's responsibility end to end, including data-fix operations. |
| Labs | Legal AI logic (content × AI) | 🔍 Not confirmed |

## Business-side users

**BizOps, CE (Customer Engagement) and CS overlap.** BizOps is a newer team that came out of CS, and CE did as well. Whether CS was split into BizOps and CE, or BizOps was added next to CS/CE, is not settled. So:
- Older tickets and docs may say "CS" for work that BizOps or CE now does.
- Don't infer someone's team from the word "CS" alone. Check the person, and when it matters, list them by name rather than by team.
- A change that affects one of these teams usually affects the others too, so tell all three.

| Team | What they do in the internal admin screen | Where their procedures are documented |
| -- | -- | -- |
| **BizOps** (including part-time staff) | Create orgs (single / CSV), trial and paid settings, user registration, approving customer requests, permissions and packs, 判例連携OP settings | BizOps wiki: 「社内管理画面について（Bizops利用範囲内）」 (Notion). **Update this page when the admin screen changes.** |
| **CE — Customer Engagement** | Operator role: org creation, approvals, editing Privilege | — |
| **構造化チーム** (content-side staff, including part-time staff) | Upload PDFs and manage bibliographic data and publishing in the production admin screen, then work in CCC | #cv-dev discussions |
| **CS** (see note above) | Relays customer inquiries as OPS tickets (Linear Asks). Whoever raised the OPS ticket is the person to ask about customer impact. | — |
| Other full-time employees | View only (search orgs, view users) | — |

## Admin screen permission levels
From the BizOps wiki:
- **管理者 (admin):** Pd and a few BizOps members. Can also physically delete users.
- **オペレーター (operator):** BizOps (including part-time staff) and CE. Org creation and approvals.
- **閲覧のみ (view only):** other full-time employees.

A change to what a role can do affects everyone who holds that role, including part-time staff who may not follow engineering announcements.

## Other surfaces
| Surface | Main users |
| -- | -- |
| Account-management Slack notifications | BizOps |
| BigQuery / Metabase billing and usage data | Corp, BizOps, analytics |
| Customer admin screen (アカウント管理画面) | Customer administrators (Privilege = 1) |
