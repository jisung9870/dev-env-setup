# PM agent job log

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
