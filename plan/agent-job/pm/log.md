# PM agent job log

## 2026-08-10 19:40 KST — Orca 단일 workspace 결정

- 사용자 결정에 따라 Windows Terminal과 iTerm2를 target bootstrap/fallback surface에서 제외했다.
- WSL과 macOS의 제품 workspace는 Orca 하나이며 tmux는 Orca worktree 내부 human partition으로 유지한다.
- cmux도 신규 제품 경로에서 제외하되 기존 Windows Terminal/cmux 구현은 즉시 삭제하지 않고 Orca 전환
  smoke와 deprecation gate를 거쳐 정리한다.
- Orca 장애 복구는 Workbench가 다른 terminal을 자동 launch하는 방식이 아니라, 사용 가능한 shell에서
  `wb`·Markdown·Git을 명시적으로 사용하는 break-glass runbook으로 제한한다.

## 2026-08-10 08:19 KST — task `task_f44f3e2fb756`

> Dispatch: `ctx_a57c4b93407a`.

### Work

- root branch가 `orca/work`이고 시작 시 tracked working tree가 clean임을 확인했다.
- root `README.md`, `plan/PRODUCT-PLAN.md`, `plan/raw/*`, Workbench `README.md`, `DESIGN.md`, `docs/*`와
  `cmd/wb`, `internal/*`, `adapters/*`의 현재 책임 경계를 검토했다.
- `plan/ARCHITECTURE.md`에 목표 구조, component ownership, current/planned distinction, client parity,
  data classification과 주요 data flow를 작성했다.
- `plan/IMPLEMENTATION-ROADMAP.md`에 staged DAG, stage별 Dashboard deliverable, acceptance/stop criteria,
  cutoff/checkpoint와 rollback policy를 작성했다.

### Decisions recorded

- Workbench는 personal operating core이고 `wb` CLI와 Dashboard는 동등 client다.
- Orca는 default cross-platform terminal/Agent workspace이며 Windows Terminal/iTerm2는 native
  bootstrap/recovery terminal이다.
- tmux는 각 Orca worktree 내부의 human session/window/pane 분리만 맡고 Orca-managed Agent는 tmux 밖에서
  실행한다. cmux는 optional/compatibility로 남긴다.
- Markdown은 human/LLM content와 important receipt의 canonical format, SQLite는 rebuildable
  projection/cache다. operational state는 C1–C3/O1–O3/Secret으로 명시 분류한다.
- external read adapter는 GitHub 다음 Slack이다. private GitHub history와 encrypted OneDrive snapshot은
  경로와 역할을 분리한다.

### Messages and reviews

- coordinator에 별도 decision request는 보내지 않았다. brief의 결정이 충분히 구체적이어서 추가 scope를
  추정하지 않고 그대로 architecture contract에 반영했다.
- 기존 문서의 `CLI primary / Dashboard auxiliary`, `tmux default workspace`, `Orca optional backend` 표현은
  현재 사실 또는 이전 방향으로 보존하고, 새 목표와 혼동되지 않도록 current-vs-planned 표를 추가했다.

### Files

- `plan/ARCHITECTURE.md` — created.
- `plan/IMPLEMENTATION-ROADMAP.md` — created.
- `plan/agent-job/pm/log.md` — created.

### Validation

- Markdown link/path, required decision keywords, stage/Dashboard/acceptance/stop/cutoff coverage를 정적 검토해
  통과했다.
- `git diff --check`가 통과했고 세 PM artifact가 non-empty임을 확인했다.
- planner/backend/frontend-owned implementation file은 수정하지 않았다.
- commit과 push는 수행하지 않는다.

### Next steps

- coordinator가 S0 artifacts를 review하고 planner/backend/frontend/validation owner별 S1–S3 task를 생성한다.
- S1 recovery gate와 S2 data classification/schema gate를 통과한 뒤에만 Orca E1과 GitHub adapter 구현을
  dispatch한다.

## 2026-08-10 08:25 KST — Phase 0 planner cross-review

### Reviewed

- planner-owned `plan/DASHBOARD-SPEC.md`, `plan/PRODUCT-PLAN.md`, `plan/README.md`,
  `plan/raw/synthesis-and-decisions.md` addendum과 `plan/agent-job/planner/log.md`를 PM architecture/roadmap과
  대조했다.
- Dashboard IA, current v1 compatibility, Core/API/action boundary, responsive/accessibility acceptance, Orca/native
  terminal/tmux/cmux ownership, Markdown/SQLite와 GitHub/OneDrive split을 검토했다.

### Specific feedback and resolution

1. **Resolved in PM docs — phase namespace:** Dashboard Phase 0–4가 delivery S0–S9와 일대일처럼 읽힐 수
   있었다. roadmap에 mapping table을 추가하고 Phase 2를 S2→S3, S4A→S4B, S7A/B→S7C gate로 분리했으며
   Phase 4의 Orca E2(S8)와 limited write(S9)를 별도 승격으로 고정했다.
2. **Resolved in PM docs — missing Dashboard acceptance:** roadmap이 planner 명세의 v1 deep-link/security,
   loading/empty/stale/partial state, WCAG 2.2 AA, keyboard/focus와 360/768/1280px acceptance를 충분히
   참조하지 않았다. 공통 Dashboard stage acceptance와 S2/S3 deliverable에 추가했다.
3. **Resolved in PM docs — recovery client parity:** 기존 S7 문구는 Dashboard가 restore를 실행하지 않는다고
   읽혀 peer-client 원칙과 충돌했다. 같은 Core restore plan/receipt를 쓰고 platform상 안전한 completion이
   불가능할 때만 same-action CLI handoff를 쓰도록 수정했다.
4. **Resolved in PM docs — receipt authority:** product/spec의 SQLite `run journal` 표현이 중요한 receipt를
   SQLite-only authority로 오해하게 할 수 있었다. architecture에서 SQLite journal은 C2/O1 portable
   authority의 query projection이라고 명시했다.
5. **Resolved in PM docs — 23:30 cutoff:** 기존 checkpoint policy에는 clock cutoff가 없었다. 23:15 new-work
   freeze, 23:30 KST status checkpoint, 이후 read-only validation/handoff, emergency containment 예외와
   `in-progress-safe` 요건을 추가했다.
6. **Consistent — current vs planned:** planner는 iTerm2와 v2 routes/actions를 Phase 0 target/unavailable로,
   v1 snapshot/action과 current ownership/security를 baseline으로 구분했다. PM architecture에도 document
   ownership과 UX Phase가 delivery stage를 대체하지 않는다는 해석을 추가했다.
7. **Consistent — ownership:** Setup 전체가 제품이고 Workbench는 logical personal operating core라는 경계,
   Dashboard/CLI peer clients, Orca runtime 단독 owner, human-only tmux partition과 optional cmux가 일치한다.
8. **Resolved concurrently by planner owner — plan discovery:** 첫 review 시점에는 `plan/README.md`에 PM
   `ARCHITECTURE.md`와 `IMPLEMENTATION-ROADMAP.md` 링크가 없었으나, cross-review 중 planner-owned diff에
   두 문서의 entry, ownership과 읽는 순서가 추가된 것을 재확인했다. PM은 해당 file을 수정하지 않았다.
9. **Resolved by document precedence — E0 ordering:** Product plan의 마지막 narrative scope 순서는 Orca E0를
   Slack 뒤로 읽을 수 있지만 같은 문서가 staged roadmap을 delivery-order owner로 지정했다. roadmap에
   S4A는 S1 뒤 S2/S3과 병행하고 S4B만 S3+E0 promotion을 기다린다는 해석을 명시했다.
10. **Resolved concurrently by planner owner — cross-document sync:** planner-owned follow-up diff가
    Dashboard spec/Product Plan/raw addendum에 PM C1–C3/O1–O3 분류, important receipt authority, S0–S9
    precedence와 `ActionPlan`/`ActionRun` identity를 반영한 것을 확인했다. PM은 해당 변경을 덮어쓰지 않았다.

### Files changed in this review

- `plan/ARCHITECTURE.md`
- `plan/IMPLEMENTATION-ROADMAP.md`
- `plan/agent-job/pm/log.md`

### Validation and next steps

- PM-owned files만 수정하고 planner/backend/frontend-owned 파일은 변경하지 않는다.
- heading/link/required decision/stage mapping/23:30 rule과 PM-owned `git diff --check`를 검증해 통과했다.
- backend/frontend task는 roadmap mapping의 underlying gate를 dependency로 사용해야 한다.

## 2026-08-10 08:44 KST — S0 implementation gate review

### Reviewed

- `workbench/docs/core-contract-baseline.md`, `workbench/docs/dashboard-compatibility.md`, backend/frontend/planner
  logs와 current Phase 0 plan을 검토했다.
- current handler/service/assets/tests를 확인해 15-action executable baseline, request-size implementation,
  existing route-only deep links와 focus rerender risk의 코드 근거를 대조했다.

### Gate decision

- **S0 accepted for S1 entry.** Architecture/Dashboard/roadmap decision, backend current-state inventory, frontend
  compatibility gap report, S1–S3 dependency와 explicit file-owner map이 모두 존재한다.
- 이것은 S1 recovery, S2 canonical data 또는 S3 client parity가 완료됐다는 뜻이 아니다. unresolved item은
  owner와 acceptance가 지정된 첫 S1 compatibility slice 또는 후속 stage로만 이동한다.

### Accepted, rejected, deferred

- **Accepted:** executable action은 15개이고 `update_secret` public docs gap이 있다.
- **Accepted decision:** total JSON action body를 16 KiB로 제한하고 >16 KiB를 mutation 전 413 stable error로
  처리한다. 승인된 16 MiB use case는 발견되지 않았다.
- **Accepted defect:** 15초 rerender/action reload focus loss를 current v1 frontend에서 bounded fix한다.
- **Rejected now:** `/activity` redirect, `/settings` split/redirect, `/runs` 등 target alias 추가, 14-row table을
  exhaustive라 주장, implemented 16 MiB limit을 evidence 없이 normative로 문서화.
- **Deferred:** selected Project/Task URL grammar는 S2 stable ID 뒤 S3 application-service gate, target IA와
  destructive action 재노출은 해당 capability/ownership gate까지 기다린다.

### Selected first slice and ownership

- Slice: **S1 v1 compatibility lock**; new IA/data/Orca behavior 없이 request limit, 15-action docs와 deterministic
  focus만 닫는다.
- Backend exclusive: `internal/dashboard/dashboard.go`, `dashboard_test.go`, `docs/dashboard.md`.
- Frontend exclusive: `internal/dashboard/assets/app.js`, 필요한 최소 `index.html`/`style.css`, new
  `internal/dashboard/testdata/focus_test.mjs`.
- Final validator는 두 lane 뒤 Go dashboard/CLI tests, Node syntax/all tests, full test/vet/build와 root diff check를
  실행한다. 자세한 success/stop/rollback/23:30 rule은 roadmap Section 7에 기록했다.

### Orca communication

- Backend owner `term_62e323ac-17ac-4043-b8b4-80bc9ccb4a0b`에 S0 acceptance, 16 KiB/15-action/route test와
  exclusive file scope를 `msg_edcbe2ed60f2`로 보냈다.
- Frontend owner `term_5c0b82de-4d83-4b3b-b902-1d09ba9acf65`에 focus-only slice, target alias 금지와 exclusive
  asset/test scope를 `msg_022df5e6c195`로 보냈다.
- Planner owner가 이미 release된 상태라 coordinator `term_01e597b5-cc85-460a-b67a-0e736f794dae`에 rendered
  compatibility route/deep-link defer 결정을 `msg_2a61be0d45e6`로 보내 routing을 요청했다.

### Files and validation

- Modified only `plan/IMPLEMENTATION-ROADMAP.md` and `plan/agent-job/pm/log.md`.
- No commit/push. PM-owned `git diff --check`, required heading/decision/owner/test/rollback/23:30 marker 검색과
  referenced Workbench file existence 검증이 통과했다. workspace의 planner-owned 변경은 건드리지 않았다.

## 2026-08-10 09:15 KST — committed S1 v1 compatibility-lock acceptance review

### Scope and evidence reviewed

- Workbench commits `e80187e`(backend)와 `6d7750c`(frontend), both full diffs, current Workbench code/docs/tests,
  backend/frontend/planner role logs, accepted roadmap와 Dashboard spec을 대조했다.
- commit은 linear하고 nested `orca/work` HEAD는 `6d7750c`다. root/nested working tree는 review 시작 시 clean했고
  data migration, provider write, root recovery, v2 route/schema 또는 Orca behavior가 없다.

### Acceptance decision

- **Implementation checkpoint accepted; release evidence open; full S1 not complete.** backend/frontend code lane과
  static/full test gate는 green이므로 두 commit은 safe rollback checkpoint로 accept한다.
- PM draft의 oversized error code `ACTION_BODY_TOO_LARGE`와 accepted implementation/spec의
  `ACTION_REQUEST_TOO_LARGE` 불일치를 후자로 정정했다. HTTP 413, fixed safe message, empty details, service call 0
  semantics는 동일하고 code/docs/tests/frontend contract가 후자에 일치한다.
- planner refinement가 허용한 six-area vocabulary/current-route mapping과 unavailable Inbox를 accepted scope로
  보았다. 새 target route/capability/state owner는 없으며 추가 `navigation_test.mjs`는 frontend testdata owner
  안이다.

### Findings

- **Accepted:** complete 16 KiB pre-decode bound; exact 16,384 execute 1 and 16,385 execute 0; unknown/trailing JSON
  rejection; all 15 v1 request shapes and public `update_secret` row; current GET/HEAD aliases and target 404s.
- **Accepted with browser gate:** focus identity는 exact existing id/data/form identity뿐이고 removed/disabled/hidden
  target은 visible `h1`로 fallback한다. frontend는 raw error message/details를 읽지 않고 bounded code/fixed copy만
  표시하며 Node 20/20이 helper/wiring을 증명한다.
- **Remaining:** real browser에서 query/hash preservation, actual DOM replacement focus, keyboard/focus ring/scroll,
  360/768/1280px와 200% zoom, hostile error/path/token/Secret sentinel의 visible DOM/accessibility tree/title zero-leak
  evidence가 없다. 이는 release acceptance blocker지만 committed code checkpoint rollback 사유는 아니다.
- **Deferred:** current scheduler/diagnostic detail의 S2/S3 threat review, selected-object deep-link grammar, target
  routes/data, shared application service와 S1 root recovery completion.

### Exact next slice, rollback and cutoff

- Next slice는 product code change를 기본값으로 하지 않는 **S1 real-browser acceptance closure**다. validation owner가
  disposable local Dashboard에서 route/bookmark, focus/action/timer, responsive/zoom/keyboard, hostile-envelope sentinel
  matrix를 실행한다.
- frontend/backend는 evidence가 자기 lane defect를 재현할 때만 exclusive assets 또는 handler/test/docs를 수정한다.
  planner는 acceptance matrix 대조, PM은 checkpoint 판정과 S1-not-done language를 소유한다.
- rollback은 필요 시 frontend `6d7750c`를 먼저, backend `e80187e`를 뒤에 commit-level revert하며 data recovery는
  없다. 23:15 new-case/fix freeze, 23:30 browser green이면 slice `accepted`, 아니면 `in-progress-safe`/lane rollback과
  exact failed evidence를 남긴다.

### Validation and communication

- PM rerun: `go test ./internal/dashboard ./internal/cli`, `go test ./...`, `go vet ./...`, `go build ./cmd/wb`,
  `node --check internal/dashboard/assets/app.js`, Node 20/20, root/nested `git diff --check`가 통과했다.
- PM-owned roadmap/log만 수정하고 code, planner/backend/frontend files, commits와 remote를 변경하지 않았다.
- Backend `term_62e323ac-17ac-4043-b8b4-80bc9ccb4a0b`에 accepted backend checkpoint와 evidence-only next owner를
  `msg_7fffed19aec3`, frontend `term_5c0b82de-4d83-4b3b-b902-1d09ba9acf65`에 accepted frontend checkpoint와
  browser gap을 `msg_3fb0eb6f3a16`으로 보냈다.
- Planner terminal은 release된 상태라 coordinator `term_01e597b5-cc85-460a-b67a-0e736f794dae`에 planner용
  acceptance/S1-not-done/browser matrix finding을 `msg_53a9e91a84d0`으로 보내 routing을 요청했다.
- Final PM-only `git diff --check`와 required status/code/commit/next-slice/owner/rollback/23:30 marker 검증이
  통과했다. workspace의 concurrent planner-owned `DASHBOARD-SPEC.md`/planner log 변경은 건드리지 않았다.

## 2026-08-10 09:15 KST — S1 Inbox focus dissent reconciliation

### Reconciled decision and evidence

- Planner의 conditional UX record는 present, keyboard-focusable `aria-disabled` Inbox를 timer rerender 후 route `h1`로
  보내는 source predicate를 product dissent로 남겼다. Frontend 보정 `e8cc586` diff는 activation-disabled와
  focus-restore-unavailable을 분리하고 present Inbox identity를 복원하며, route/action/API/state owner를 추가하지
  않는다.
- 보정 fixture는 rerender로 old Inbox node를 교체한 뒤 exact identity를 복원하고 removal notice가 0건임을
  검증한다. removed, native-disabled, hidden-attribute/CSS-hidden target의 route-`h1` fallback과 destructive-neighbor
  avoidance는 유지된다.
- **Source-level Inbox focus defect resolved; release evidence open; full S1 not complete.** `node --check`, frontend
  Node 20/20, `go test ./internal/dashboard ./internal/cli`와 nested `git diff --check`가 통과했다. 이 결과는
  actual browser fetch/render lifecycle 또는 responsive/accessibility acceptance를 대체하지 않는다.

### Exact next slice, owners, rollback and cutoff preserved

- Next slice는 계속 product code change를 기본값으로 하지 않는 **S1 real-browser acceptance closure**다.
  Validation owner는 disposable local Dashboard에서 current five routes+Guide, query/hash bookmarks, manual/timer/action
  success/failure focus, keyboard, 360/768/1280px, 200% zoom, themes, focus/target/text/overflow/scroll과 hostile-envelope
  sentinel DOM/accessibility-tree/title matrix를 그대로 실행한다.
- Frontend/backend는 browser evidence가 자기 lane defect를 재현할 때만 각각 assets/browser fixture 또는
  handler/test/docs를 exclusive로 수정한다. Planner는 screenshot/accessibility evidence를 acceptance matrix에
  대조하고, PM은 checkpoint와 S1-not-done language를 소유한다.
- Rollback은 data recovery 없이 `e8cc586` 보정을 먼저, frontend lane 전체가 필요하면 `6d7750c`,
  필요하면 backend `e80187e` 순으로 commit-level revert한다. 23:15 new-case/fix freeze와 23:30
  green 시 `accepted`, 아니면 `in-progress-safe`/lane rollback+exact failed evidence cutoff은 그대로다.
- Frontend owner `term_5c0b82de-4d83-4b3b-b902-1d09ba9acf65`에 reconciliation을 `msg_88f177fea481`로
  알렸다. Planner terminal은 release된 상태라 coordinator `term_01e597b5-cc85-460a-b67a-0e736f794dae`에
  planner용 결론을 `msg_e7d30cbff8a2`로 보내 routing을 요청했다.
