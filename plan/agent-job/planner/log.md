# Product planner 작업 로그

## 2026-08-10 08:21 KST — Phase 0 Dashboard specification

### 작업

- 현행 제품 계획과 raw synthesis/current-system/user-scenario 자료를 검토했다.
- Workbench Dashboard 문서, backend/Agent/worktree 계약, Design 문서와 embedded Dashboard route/action assets를
  구현 기준선으로 확인했다.
- operations console을 유지하면서 목표 IA와 화면 상태, 반응형·접근성, Core/API, no-second-state-owner,
  typed mutation safety, 단계별 deliverable/acceptance test를 `plan/DASHBOARD-SPEC.md`에 작성했다.
- 제품 계획과 plan index에는 필요한 결정과 링크만 추가하고 raw synthesis에 날짜가 있는 addendum을 남겼다.

### 가정

- `DASHBOARD-SPEC.md`의 v2 route/envelope/action 이름은 Phase 0 target contract이며 현재 구현 완료 상태가 아니다.
- iTerm2는 확정된 native fallback 방향이지만 현 Workbench backend 구현에는 없으므로 구현·실장 smoke 전에는
  unavailable capability로 표시한다.
- 현재 v1 route/action은 안전 계약과 deep link를 보존한 compatibility 단계 뒤에만 이행한다.
- Orca는 기본 workspace/runtime owner지만 Workbench의 장기 project/task/ref/run index를 대신 소유하지 않는다.

### 검토 질문

- backend RFC에서 v2 area query를 여러 endpoint로 나눌지, schema-v1 snapshot 안에서 먼저 additive하게
  제공할지 결정해야 한다.
- canonical Markdown 최소 frontmatter와 rename/revision 규칙은 별도 schema prototype에서 확정해야 한다.
- Orca worktree와 human tmux partition의 stable link field 및 iTerm2 capability contract는 backend owner와
  fixture를 합의해야 한다.
- current destructive v1 actions 중 어느 것을 새 IA에 재노출할지는 각 phase ownership gate에서 재검토한다.

### 변경 파일

- `plan/DASHBOARD-SPEC.md`
- `plan/PRODUCT-PLAN.md`
- `plan/README.md`
- `plan/raw/synthesis-and-decisions.md`
- `plan/agent-job/planner/log.md`

### validation

- branch가 `orca/work`인지 확인했다.
- planner-owned `plan/` 문서만 변경하고 Workbench frontend/backend/PM-owned 구현 파일은 수정하지 않았다.
- `git diff --check`가 통과했다.
- 문서 link target이 존재하고 핵심 결정 문구와 Markdown heading 구조가 포함됐는지 검사했다.

### 다음 단계

1. PM이 Phase 0 범위와 성공 지표의 일관성을 검토한다.
2. backend owner가 Markdown/projection schema와 shared Core query/action RFC를 작성한다.
3. frontend owner가 current v1 compatibility map을 기준으로 navigation shell과 공통 상태 component를 설계한다.
4. QA/접근성 owner가 Phase 1 viewport, keyboard, screen reader와 security fixture를 test plan으로 변환한다.

## 2026-08-10 08:26 KST — PM architecture/roadmap cross-review

### 검토 범위

- PM-owned `plan/ARCHITECTURE.md`, `plan/IMPLEMENTATION-ROADMAP.md`, `plan/agent-job/pm/log.md`를 끝까지 읽고
  planner-owned Dashboard spec, product plan, plan index와 synthesis addendum을 대조했다.
- current/planned 구분, runtime owner, data authority, client parity와 stage별 Dashboard acceptance를 중점 검토했다.

### 구체 feedback과 resolution

1. **Stage 이름 불일치:** Dashboard spec의 Phase 1–4가 PM roadmap의 S0–S9 dependency를 뭉갰다. Section 10을
   S0, S1, S2, S3, S4A/B, S5/6, S7A/B/C, S8/9 Dashboard deliverable/acceptance로 교체하고, 기존 Phase
   0–4는 PM mapping과 같은 UX workstream alias로만 보존했다.
2. **IA 축약어:** PM roadmap S0/S3의 `Runs`, `Recovery`는 제품 IA의 `Runs & Agents`, `System & Recovery`보다
   짧다. PM file은 ownership상 수정하지 않고 두 표현을 user-facing label의 축약어로 명시해 두 navigation
   owner가 생기지 않게 했다.
3. **runtime 표현:** Orca default와 E0/E1 planned 상태를 함께 유지하고 Windows Terminal/iTerm2는
   bootstrap/recovery, tmux는 worktree 내부 human-only, Orca Agent는 tmux 밖, cmux는
   optional/compatibility로 통일했다. 현재 Orca/iTerm2 adapter 구현 완료를 주장하지 않는다.
4. **Markdown/SQLite 과단순화:** 기존 spec은 중요한 receipt와 pending mutation을 모두 rebuildable projection
   문구에 포함할 위험이 있었다. C1–C3/O1–O3/Secret을 등록하고 C2 receipt와 O1 journal을 SQLite 밖 durable
   authority에 먼저 확정하도록 수정했다.
5. **mutation identity:** 기존 JSON 예시의 `action`/`stable_action_id`가 action type과 run identity를
   혼동했다. 비규범 예시로 낮추고 `action_type`, Core-issued `action_id`, `plan_hash`, target revision과
   idempotency를 분리했다.
6. **parity 측정:** “같은 Core 사용” 선언을 넘어 같은 fixture/action의 plan hash, state transition,
   outcome/error code와 receipt schema mismatch 0을 product plan과 S3 acceptance에 반영했다.
7. **문서 탐색:** plan index가 PM artifact를 등록하지 않아 architecture/roadmap을 source-of-truth table과
   읽는 순서에 추가했다.
8. **restore parity:** 초기 planner 문구는 Dashboard를 restore preview-only로 고정해 peer-client contract보다
   좁았다. 같은 Core restore plan을 foreground approval 뒤 안전하게 완료할 수 있으면 Dashboard도 실행하고,
   platform이 completion을 보장하지 못할 때만 같은 `action_id`의 exact CLI handoff를 쓰도록 정렬했다.
9. **E0 순서:** Product Plan의 마지막 narrative가 Orca E0를 Slack 뒤로 읽히게 했다. S4A는 S1 뒤 S2/S3과
   병행하고 S4B만 S3+E0 promotion을 기다리도록 critical path/branch 문구로 교체했다.

### 남은 owner 질문

- S2 acceptance 전에는 v2 endpoint/field 이름을 고정하지 않는다. backend owner가 schema와 application-service
  RFC에서 concrete name을 제안하고 frontend는 같은 contract를 소비해야 한다.
- current v1 action의 target area mapping과 file-owner change map은 S0 frontend gap report에서 수량화해야 한다.
- accessibility/browser smoke command와 screen-reader 조합은 validation owner가 S1–S3 test plan에 고정해야 한다.

### 변경 파일

- `plan/DASHBOARD-SPEC.md`
- `plan/PRODUCT-PLAN.md`
- `plan/README.md`
- `plan/raw/synthesis-and-decisions.md`
- `plan/agent-job/planner/log.md`

### validation

- `git diff --check`가 통과했고 planner 문서의 local Markdown link/path가 모두 존재함을 확인했다.
- PM terminology, Phase alias→S0–S9 mapping, C1–C3/O1–O3, same-action restore, measurable acceptance keyword를
  정적 검사했다.
- PM-owned architecture, roadmap와 PM log는 수정하지 않으며 commit/push도 수행하지 않는다.

## 2026-08-10 08:46 KST — S0 product/UX gate review

### reviewed evidence

- S0 backend baseline `workbench/docs/core-contract-baseline.md`와 frontend baseline
  `workbench/docs/dashboard-compatibility.md`를 전체 검토했다.
- PM, planner, backend, frontend 네 role log와 `DASHBOARD-SPEC.md`, `PRODUCT-PLAN.md`, `ARCHITECTURE.md`를
  대조했다.
- current handler/action/assets/tests에서 15-action 실행 표면, request bound, route-only state, 15초 full render,
  path/error DOM과 responsive/accessibility evidence를 확인했다.

### product-facing decisions

1. executable v1 baseline은 `update_secret`을 포함한 15 actions다. `update_secret`은 `/settings` compatibility에서
   payload/value clearing/metadata-only boundary를 유지하고, Integrations target screen에는 S2/S3 전 복제하지
   않는다. target owner는 Integrations, store recovery observation은 System & Recovery read다.
2. action request normative maximum은 문서대로 16 KiB(16,384 bytes)로 선택했다. 16,385 bytes 이상은 HTTP
   413/service call 0/fixed safe copy이며 body/decoder diagnostic은 echo하지 않는다.
3. S1은 새 route/redirect를 만들지 않는다. `/`, `/projects`, `/activity`, `/settings`, `/system`을 target label에
   mapping하고 Inbox는 focusable unavailable item이다. `/activity`는 future `/runs` 뒤 rendered alias로 최소 한
   release 유지하며 explicit 30-day observation에서 use 0이 아니면 제거하지 않는다. `/settings`는 두 target
   owner의 compatibility index라 단일 redirect를 금지한다.
4. full-refresh focus loss는 S1 visible slice blocker다. existing stable id/data key로 focus를 복구하고 대상이
   사라지면 route `h1`+polite removal notice로 이동한다. label/DOM position으로 identity를 추측하지 않는다.
5. raw server `message/details`, command/stdout/stderr, home/cwd/registry/tmux path와 Secret sentinel은 generic DOM,
   accessibility tree와 title에 render하지 않는다. canonical project path는 existing Project detail, exact recovery
   path/command는 explicit System disclosure에서만 보존하며 새 shell/Today로 복제하지 않는다.
6. six areas는 navigation vocabulary로 한 번에 보이되 capability는 stage별 enable한다. label 존재는 domain
   완료가 아니며 current destructive action을 새 area에 promotion하지 않는다.

### smallest paired slice

- **Frontend:** focus-safe six-area compatibility shell—target labels/current route mapping, unavailable Inbox,
  one visible `h1`, active semantics, refresh state, persistent safe failure summary와 deterministic focus return만
  구현한다.
- **Backend evidence:** exact 15-action inventory/`update_secret` zero-leak, 16,384 accepted vs 16,385 HTTP 413 and
  service 0, raw error/path/Secret sentinel exclusion, complete v1 route/security/action regression을 같은 checkpoint에
  제공한다.
- 둘 중 하나만 완료되면 release하지 않는다. concrete S2/S3 object, endpoint, field, URL parameter 또는
  `ActionPlan/ActionRun` schema는 이 slice에 없다.

### exact acceptance and accessibility/responsive fixtures

- 15 action IDs를 정확히 한 번씩 exercise하고 unknown 16th/nested Secret field를 실행 전 거부한다.
- minimal valid JSON+whitespace exact 16,384 bytes는 service 1, 16,385 bytes는 HTTP 413/service 0이며 response/log
  sentinel은 0이다.
- `/activity?source=bookmark#task-detail`, `/settings?source=bookmark#secrets`는 load/refresh 뒤 path/search/hash가
  byte-for-byte 같다. S1의 planned `/today|inbox|runs|integrations`는 404와 UI copy가 모순되지 않는다.
- project/task/Refresh/Secret submit/Inbox control × manual/timer/success/failure matrix에서 same key focus 또는
  missing-target `h1` focus가 100%, body focus loss가 0이다.
- 360/768/1280, 200% zoom, light/dark/system, reduced motion에서 one `h1`, named landmarks/nav, keyboard order,
  visible focus, 44×44 targets, 16px text, `scrollWidth <= clientWidth`, content/focus loss 0을 real browser로 확인한다.
- Unix/Windows path, `sec://`, token, command/stdout/stderr sentinel은 response user copy, DOM, accessibility tree와
  title attribute에 0건이다.

### non-goals

- 새 target route/redirect/deep-link grammar, Inbox/Today/Run data, Markdown/SQLite/v2 schema와 browser state store.
- `update_secret` migration, provider account model, structured S3 error field, current destructive action promotion.
- Orca/iTerm2/connector/install/repair/retry/fallback implementation, framework migration과 remote dependency.

### PM/backend/frontend feedback and deferred owners

- **PM:** slice+backend evidence를 한 S1 checkpoint로 묶고 label/capability를 분리해 report해야 한다.
- **Backend:** public 15-action inventory, 16 KiB/413 boundary, safe error response와 S1 recovery capability source를
  소유한다. `err.Error()`/details를 generic browser response로 보내지 않는다.
- **Frontend:** v1 action adapter/payload를 유지하면서 nav/focus/safe-notice seam만 소유하고 route handler/schema를
  만들지 않는다. browser harness 없는 Node/Go 결과로 acceptance를 주장하지 않는다.
- **Validation:** route/search/hash, timer/action focus, accessibility tree sentinel과 responsive/zoom matrix를
  real browser에서 실행한다.
- S2/S3로 defer: stable object URL grammar, path allowlist, structured error/recovery contract, Settings final split,
  profile/credential view model과 alias retirement mechanism.

### files and validation

- 변경: `plan/DASHBOARD-SPEC.md`, `plan/agent-job/planner/log.md`만.
- `git diff --check`와 두 planner file의 local Markdown link 검사가 통과했다.
- six decisions, 15-action/16 KiB/route/focus/sentinel/browser fixture, non-goal/deferred owner와 owned-file diff를
  정적 검토했다.
- PM/backend/frontend baseline/log와 runtime files는 수정하지 않고 commit/push도 하지 않는다.
