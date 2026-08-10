# Setup staged implementation roadmap

> 상태: **Phase 0 delivery plan**  
> 기준일: 2026-08-10  
> 아키텍처: [ARCHITECTURE.md](ARCHITECTURE.md)  
> Dashboard workstream: [DASHBOARD-SPEC.md](DASHBOARD-SPEC.md)
> 제품 gate: [PRODUCT-PLAN.md](PRODUCT-PLAN.md)

## 1. delivery 원칙

로드맵은 날짜만으로 승격하지 않고 dependency, evidence와 stop criteria로 진행한다. 각 stage는 CLI,
Dashboard, data/recovery, validation 전달물을 함께 갖는다. stage가 끝날 때 current facts, planned next step,
검증 artifact와 rollback point를 checkpoint로 고정한다.

- WSL은 primary Tier-1 후보이며 macOS는 같은 smoke track에서 독립 판정한다.
- root와 child repo ownership을 지킨다. root는 profile/manifest/integration contract, Workbench는 core/clients,
  nvim/binbox는 terminal/editor fallback, cmux-config는 optional compatibility를 소유한다.
- 첫 external read adapter는 GitHub, 다음은 Slack이다.
- Orca는 기본 workspace 목표지만 E0/E1 gate를 통과하기 전에는 현재 구현 기능이라고 부르지 않는다.
- 한 stage의 Dashboard는 후속 polish가 아니라 acceptance 대상이다.

## 2. staged DAG

```mermaid
flowchart LR
    S0["S0 Phase 0\narchitecture + baseline"] --> S1["S1 trust foundation\nprofile + manifest + restore"]
    S1 --> S2["S2 canonical core\nMarkdown + operational classes"]
    S2 --> S3["S3 client parity\nInbox/Today/Project loop"]
    S1 --> S4A["S4A Orca E0\nusage baseline"]
    S3 --> S4B["S4B Orca E1\nread/open/jump"]
    S4A --> S4B
    S3 --> S5["S5 GitHub read adapter"]
    S5 --> S6["S6 Slack read adapter"]
    S2 --> S7A["S7A private GitHub history"]
    S1 --> S7B["S7B encrypted OneDrive snapshot"]
    S7A --> S7C["S7C clean restore drill"]
    S7B --> S7C
    S4B --> S8["S8 Orca E2 controlled launch"]
    S6 --> S9["S9 limited write candidate"]
    S7C --> S9
    S8 --> S9
```

Critical path는 `S0 → S1 → S2 → S3 → S5 → S6`이다. S4A와 backup 두 branch는 선행조건이 충족되면
병행할 수 있지만, 같은 file owner를 공유하는 implementation task는 병렬 edit하지 않는다. S8과 S9는
30일 MVP 밖의 조건부 stage다. `PRODUCT-PLAN.md`의 30/90일 horizon이나 마지막 scope 순서가 이 DAG와 다르게
읽히면 이 문서의 dependency가 실행 순서를 소유한다. 특히 Orca E0(S4A)는 Slack 뒤에 기다리는 작업이 아니라
S1 뒤 S2/S3과 병행해 표본을 모으며, E1(S4B)만 S3과 E0 promotion을 모두 기다린다.

### Dashboard Phase 0–4와 delivery DAG의 관계

`DASHBOARD-SPEC.md`의 Phase는 UX workstream 묶음이고 이 문서의 dependency gate를 압축하거나 건너뛰지
않는다.

| Dashboard phase | delivery stage mapping | dependency/해석 |
|---|---|---|
| Phase 0 결정·계약 | S0 | 명세, compatibility map과 gap report만 완료한다. v2 route/action은 구현 완료가 아니다. |
| Phase 1 Core parity·compatibility shell | S1의 System & Recovery slice + S3 client-parity foundation | nav/alias/common state는 S0 뒤 시작할 수 있지만 canonical mutation parity는 S2 data contract 뒤 S3에서 accept한다. |
| Phase 2 local closed loop | S2 → S3, workspace는 S4A → S4B, off-device restore는 S7A/S7B → S7C | 한 번에 release하는 단일 phase가 아니다. 각 card/action은 underlying stage gate를 통과한 capability만 노출한다. |
| Phase 3 external read connector | S5 → S6 | GitHub acceptance 전 Slack code와 UI를 시작하지 않는다. |
| Phase 4 controlled execution·limited write | S8 및 별도 S9 | S8은 S4B+S7C 뒤, S9는 S6+S7C(Agent write면 S8도) 뒤다. 두 기능을 같은 승격으로 묶지 않는다. |

모든 Dashboard slice는 명세의 loading/empty/stale/partial/blocked/unknown/unavailable state, WCAG 2.2 AA,
360/768/1280px responsive, keyboard/focus와 current v1 security/compatibility regression을 해당 stage의
acceptance에 포함한다. planner 명세가 화면과 interaction의 source이고 이 roadmap은 언제 claim할 수 있는지를
정한다.

## 3. 모든 stage에 적용하는 definition of done

1. **Contract:** owner, input/output, current/planned 문구와 failure state가 문서화됐다.
2. **CLI:** query 또는 action을 automation/SSH에서도 수행하고 machine-readable result를 얻는다.
3. **Dashboard:** 같은 core query/action의 stage-specific view, stale/error/recovery state를 제공한다.
4. **Parity:** 같은 fixture에서 CLI와 Dashboard가 같은 action plan, outcome/error code와 receipt를 만든다.
5. **Recovery:** disable/export와 checkpoint/rollback 또는 rebuild 경로를 검증했다.
6. **Security:** Secret/context/authority negative test를 통과했다.
7. **Evidence:** build, fixture, 실제 장비 smoke를 구분한 validation record가 있다.
8. **Cutoff:** stage checkpoint가 기록되고 미완료 항목은 다음 stage로 암묵적으로 넘어가지 않는다.

## 4. stage별 deliverable과 gate

### S0 — Phase 0 architecture와 baseline

**목표:** 결정을 잠그고 구현 팀이 충돌 없이 task를 자를 수 있게 한다.

**Deliverables**

- 이 architecture와 roadmap, component ownership 및 staged DAG.
- 기존 Workbench package/CLI/Dashboard/file boundary의 current-state inventory.
- Workbench core, `wb`, Dashboard, root setup, Orca, tmux, native terminal, cmux의 owner matrix.
- data classification(C1–C3, O1–O3, Secret)과 current-vs-planned wording rule.
- Dashboard: 현재 route/action inventory를 새 IA(Today, Inbox, Projects, Runs, Integrations, Recovery)에 mapping한
  read-only gap report. 구현 변경은 S0에 포함하지 않는다.

**Acceptance**

- coordinator brief의 모든 결정이 architecture에 명시돼 있다.
- dependency depth가 4 이하인 task DAG로 S1–S3을 분해할 수 있다.
- planner/backend/frontend owner가 같은 file을 동시에 수정하지 않는 change map이 준비된다.

**Stop**

- Workbench/Orca/tmux 중 live Agent lifecycle의 mutation owner를 하나로 정할 수 없으면 S1 이후 Agent 작업을
  시작하지 않는다.
- SQLite에 둘 operational state의 authority를 분류하지 못하면 schema implementation을 시작하지 않는다.

#### 2026-08-10 S0 implementation gate 판정

**판정: ACCEPTED — S1 진입 허용, S1/S2/S3 완료를 의미하지 않음.**

근거는 `workbench/docs/core-contract-baseline.md`와 `workbench/docs/dashboard-compatibility.md`가 current API,
store/runtime authority, 15개 executable action, route/deep-link, sensitive DOM, accessibility/responsive gap,
S1–S3 fixture와 zero-overlap file-owner map을 current/planned로 분리해 기록했고, backend/frontend baseline test가
통과했다는 것이다. 남은 불일치는 owner와 stage를 지정할 수 있으므로 S0 blocker가 아니라 아래 첫 S1 slice와
후속 gate로 이동한다.

| finding | 판정 | resolution/owner |
|---|---|---|
| executable Dashboard action은 15개이며 `update_secret`이 public 14-row table에서 빠짐 | **accepted fact** | backend docs owner가 첫 slice에서 table을 15개로 정렬하고 existing typed/redaction tests를 보존한다. |
| code는 약 16 MiB+64 KiB, docs/Guide는 16 KiB request limit | **16 KiB 선택** | total JSON body hard limit를 16 KiB로 code/docs/test에서 일치시킨다. 현재 action은 typed metadata/single Secret field이며 16 MiB payload의 승인된 use case가 없다. |
| `/activity`, `/settings`를 지금 redirect/target alias로 변경 | **rejected for first slice** | 두 route는 S3 compatibility window까지 rendered route로 유지한다. `/docs`만 현행 Guide alias로 유지하며 `/runs` 등 target route를 오늘 추가하지 않는다. |
| current selected Project/Task deep link | **deferred** | current contract는 route-only다. stable object ID/URL grammar는 S2 schema 뒤 S3 application service가 소유한다. query/fragment를 새 meaning으로 추측하지 않는다. |
| 15초 rerender와 action reload가 focus를 잃음 | **accepted S1 defect** | frontend가 current v1 DOM 안에서 stable focus key/restore fallback과 regression test만 추가한다. target navigation/state는 만들지 않는다. |
| `/settings` split, `/activity`→`/runs`, destructive action 재노출 | **deferred** | S2/S3 capability, owner와 migration fixture 전에는 compatibility UI를 유지한다. |

16 KiB는 request 전체의 UTF-8 byte 수(`16 << 10`)다. 초과 요청은 service mutation 전 HTTP 413과 stable
`ACTION_REQUEST_TOO_LARGE`를 반환한다. 유효한 16 KiB 이하 JSON은 기존 typed decoder를 통과하며 unknown/trailing
field 오류는 기존 400 contract를 유지한다. 16 KiB를 넘는 실제 Secret/typed action 요구가 fixture로
발견되면 16 MiB로 자동 회귀하지 않고 Secret transport와 storage threat review를 별도 decision gate로 연다.

### S1 — trust foundation와 recovery shell

**목표:** 새 domain 전에 설치, native recovery와 검증 조합을 신뢰할 수 있게 한다.

**Dependencies:** S0.

**Root/setup deliverables**

- default `workbench` profile과 explicit `terminal` recovery profile의 selector/preflight/exit contract 정렬.
- WSL에서 Windows Terminal, macOS에서 iTerm2를 쓰는 bootstrap/doctor/restore runbook.
- child commit, platform, date, validation run, expiry(90일), rollback을 가진 verified manifest.
- dirty child preservation, no-force update, synthetic corruption restore fixture.

**Workbench/clients deliverables**

- CLI: `doctor`, portable inventory, backup/verify/restore dry-run의 기준 contract.
- Dashboard: System & Recovery view에 profile, capability tier, manifest freshness, last verified checkpoint,
  recovery command를 표시. install/repair 자동 실행은 하지 않는다.

**Acceptance**

- WSL fresh setup + doctor 2회, update 2회, synthetic restore 1회.
- macOS는 같은 smoke를 별도 결과로 기록; 미통과면 experimental 표기.
- Workbench/Orca 없이 native terminal에서 Markdown/Git/tmux fallback 진입 성공.
- profile 문서, selection output과 exit code가 일치.

**Stop/cutoff**

- 수동 삭제, force Git 또는 사용자 dirty state 손실이 필요하면 모든 새 기능을 동결한다.
- manifest input이 하나의 검증 run에서 나오지 않았거나 rollback이 없으면 stage를 닫지 않는다.

### S2 — canonical Markdown core와 operational state

**목표:** connector 없이 portable personal model과 rebuildable projection을 증명한다.

**Dependencies:** S1.

**Core/data deliverables**

- `Context`, `InboxItem`, `Project`, `Task`, `ExternalRef`, `WorkLocation`, `Run`의 최소 Markdown schema.
- stable ID, rename/link, schema migration, concurrent edit와 corrupt/truncated fixture.
- C1–C3/O1–O3 classification enforcement; unclassified state 추가를 CI에서 거부하는 schema review checklist.
- SQLite projection/cache: lexical search, dedupe candidate, Today query, source/observed time; delete/rebuild command.
- important receipt와 O1 checkpoint를 portable journal에 먼저 확정한 뒤 projection하는 write protocol.

**CLI deliverables**

- capture/import, show/search, projection rebuild, export/import, receipt inspect.
- rebuild 전/후 record count, stable ID, hash와 query equivalence 검증.

**Dashboard deliverables**

- read-only Inbox/Today/Project skeleton, projection freshness, rebuild status와 canonical file link.
- Markdown parse error를 숨기지 않고 file/field/recovery guidance를 보여준다.
- 새 IA shell과 common state component는 schema-ready capability만 enable하고, 준비되지 않은 v2 query/action은
  unavailable/준비 중으로 표시한다. 현재 v1 deep link와 typed action을 자동으로 제거하거나 재노출하지 않는다.

**Acceptance**

- SQLite와 sidecar를 삭제한 clean rebuild 뒤 canonical object와 important receipt 유실 0.
- export→clean import→rebuild 후 stable relation 100% 유지.
- Secret fixture가 Markdown, SQLite, search result, logs와 Dashboard snapshot에 나타나지 않음.
- personal/work cross-context write는 기본 fail-closed.

**Stop/cutoff**

- frontmatter rename이 stable link를 보존하지 못하거나 O1을 DB 없이는 복구할 수 없으면 schema를 동결하지
  않고 prototype으로 되돌린다.
- 전면 SQLite migration이 필요해지면 별도 decision gate 없이 진행하지 않는다.

### S3 — CLI/Dashboard parity의 첫 closed loop

**목표:** `capture → classify → Today/Next → resume → review/receipt`를 두 client에서 완주한다.

**Dependencies:** S2.

**Core deliverables**

- client-neutral application service와 typed `ActionPlan/ActionRun`.
- risk, target, context/account, plan hash, approval, checkpoint, reconcile, recovery hint.
- `received/staged/applied/reviewed/blocked/retryable/partial/unknown` 상태.

**CLI deliverables**

- 10초 capture 경로, batch/search, action preview/apply, exact action resume와 recovery output.

**Dashboard deliverables**

- Today, Inbox triage, Project resume, Runs/recovery panel.
- same plan hash 승인, stale-plan rejection, terminal-required action의 exact CLI handoff.
- browser refresh/server failure에도 canonical data를 손상하지 않는 error state.
- `DASHBOARD-SPEC.md` Phase 1 acceptance인 v1 security/deep-link regression, keyboard landmark/focus, 360/768/1280px
  content-loss 검증을 통과한다.

**Acceptance**

- 실제 Inbox 20개와 closed loop 3개, provenance 100%.
- capture median ≤10초; resume median ≤60초 또는 baseline 대비 30% 개선.
- CLI/Dashboard parity fixture에서 plan/outcome/error/receipt mismatch 0.
- partial failure마다 surviving asset과 next action 표시 100%.

**Stop/cutoff**

- 20개 표본 전에 두 번째 external adapter, native app 또는 새 automation domain을 시작하지 않는다.
- Dashboard 자발적 resume 사용이 4주간 50% 미만 또는 browser fallback이 20% 초과면 Dashboard를 review/ops
  peer로 유지하되 workspace launcher 확장은 중단한다. 이는 client parity 포기가 아니라 역할 조정이다.

### S4A — Orca E0 usage baseline

**목표:** 기본 workspace 전환의 실제 가치와 migration 대상을 관찰한다.

**Dependencies:** S1; S2와 병행 가능.

**Deliverables**

- 2주 또는 Agent session 20개의 category-only 기록: Orca/direct/tmux, start/resume/result time, fallback,
  permission profile. prompt/path/output은 기록하지 않는다.
- human tmux-inside-worktree와 Orca-Agent-outside-tmux 운영 runbook.
- Dashboard: Integrations/Workspace card에 E0 sample size, current default, fallback과 readiness gate 표시.

**Acceptance / promotion**

- Orca가 session의 30% 이상이거나 Workbench에서 Orca session을 찾고 싶은 사례 3회 이상이면 S4B로 간다.

**Stop**

- Orca가 실사용되지 않거나 current terminal path가 같은 문제를 충분히 해결하면 integration을 시작하지
  않고 native recovery + tmux 계약만 유지한다.

### S4B — Orca E1 read/open/jump

**목표:** Orca를 기본 workspace로 안전하게 찾아가되 lifecycle을 복제하지 않는다.

**Dependencies:** S3 + S4A promotion.

**Deliverables**

- capability/version/health, read-only worktree/Agent summary, `observed_at`, confidence.
- canonical repo/path/branch 재검증 후 open/jump; runtime handle은 매번 재탐색.
- Workbench Task/Run에 opaque provider ref와 result pointer 연결.
- CLI: status/list/open/jump, `--json`, explicit unavailable and native recovery guidance.
- Dashboard: Workspace/Project에서 Orca state, staleness, open/jump와 result pointer; stop/remove 없음.
- tmux pane observation을 Orca Agent state와 분리하는 migration/compatibility label.

**Acceptance**

- 20회 resume에서 wrong-worktree jump 0, stale handle 재탐색 ≥95%, Orca 부재 fallback 100%.
- CLI/Dashboard가 같은 canonical target와 capability error를 표시.

**Stop**

- 30일 내 typed contract break 2회, transcript scraping 필요, identity ambiguity >1%, Workbench의 Orca state
  양방향 복제가 필요하면 jump-link 수준으로 축소한다.

### S5 — GitHub read adapter

**목표:** 첫 external account/context/cursor/reconcile 계약을 실제로 검증한다.

**Dependencies:** S3.

**Deliverables**

- 최소-scope account/context config와 credential reference; issue/PR/review 등 선정 metadata만 pull.
- source ID/revision, cursor epoch, received/observed time, deep link, dedupe, full reconcile.
- disconnect, revoke guidance, cached projection keep/delete choice, portable export.
- CLI: connect health, sync dry-run/run, status, reconcile, disable/export.
- Dashboard: Integrations health/scope/account/staleness, Inbox provenance, manual sync/reconcile와 disconnect preview.

**Acceptance**

- duplicate/out-of-order/missed event, cursor reset, 429/5xx, revoke, wrong account/context fixture 통과.
- 원문 유실/자동 덮어쓰기 0, plaintext credential 0, external write 0.
- 30일 실제 read use가 manual navigation 또는 triage 시간을 줄였다는 표본 확보.

**Stop**

- write scope가 read에 필요하거나 account/context를 확실히 표시할 수 없거나 cursor reconciliation이
  수렴하지 않으면 adapter를 deep-link-only로 축소한다.

### S6 — Slack read adapter

**목표:** GitHub에서 증명된 공통 read contract를 두 번째 provider에서 재사용한다.

**Dependencies:** S5 acceptance.

**Deliverables**

- 선정 channel/thread metadata와 deep link만 수집하는 최소 scope adapter.
- GitHub와 동일한 event envelope, cursor/reconcile, health, disable/export; Slack-specific rate limit과
  retention은 adapter 내부에 보존.
- CLI와 Dashboard의 GitHub/Slack 공통 Integrations surface, provider-specific detail disclosure.

**Acceptance**

- 공통 contract의 핵심 구현/fixture를 재사용하고 provider 차이는 typed extension으로만 남김.
- duplicate/retry/rate-limit/revoke/stale/retention fixture 통과; message body 보존은 명시된 최소 범위 밖 0.
- GitHub projection을 깨뜨리지 않는 독립 disable/rebuild.

**Stop**

- Slack을 위해 generic plugin SDK, public webhook relay 또는 broad message archive를 선행해야 하면 보류한다.
- GitHub contract를 재사용할 수 없으면 공통 abstraction을 억지로 만들지 않고 architecture decision을 다시
  연다.

### S7 — history, encrypted snapshot와 restore

**목표:** Git history와 off-device snapshot의 역할을 분리해 실제 복구한다.

**Dependencies:** S7A는 S2, S7B는 S1, clean restore(S7C)는 둘 모두.

**Deliverables**

- S7A: private GitHub repository에 Markdown/config만 commit하는 include/exclude, review와 conflict policy.
- S7B: Secret 제외 manifest, hashes, schema/app version, retention을 가진 encrypted OneDrive snapshot.
- live Git working tree와 OneDrive staging/snapshot path 물리 분리.
- CLI: snapshot create/verify/list/restore-dry-run; Dashboard: last snapshot/verification/restore drill, expiry와
  recovery location. Dashboard는 같은 Core restore plan을 preview하고 foreground approval 뒤 실행한다. browser
  process restart 등으로 안전한 completion을 보장할 수 없는 platform에서는 같은 `action_id`의 exact CLI
  handoff를 제공한다. 어느 경로도 plaintext key를 browser payload로 받지 않는다.

**Acceptance**

- clean environment에서 Git history restore + latest verified snapshot decrypt/checksum + projection rebuild +
  doctor 성공.
- 같은 path 이중 sync 0, plaintext Secret/age key 0, repeated conflict 0.

**Stop**

- byte/content ownership 충돌, plaintext leak 또는 key recovery 부재가 한 건이라도 있으면 해당 provider
  automation을 중단하고 local verified snapshot으로 되돌린다.

### S8 — Orca E2 controlled launch (조건부)

**목표:** Orca E1 가치가 증명된 뒤 safe launch와 result pointer를 추가한다.

**Dependencies:** S4B acceptance + S7C recovery.

**Deliverables**

- agent, worktree, setup policy, effective permission을 보여주는 launch plan.
- `safe` default, explicit `trusted-local`/`infrastructure`; full bypass는 per-session high-risk receipt.
- Orca가 launch owner이며 Workbench는 idempotency intent와 opaque result pointer만 보존.
- CLI/Dashboard 동일 preview/approval; Dashboard는 terminal interaction이 필요하면 action handoff.

**Acceptance**

- 비파괴 coding task 10개: policy 표시 100%, result pointer ≥90%, duplicate launch 0, credential leak 0.

**Stop**

- Orca bypass default를 override/verify할 수 없거나 launch retry fencing이 불가능하거나 orphan worker 1건이면
  즉시 E1 read/open/jump로 rollback한다.

### S9 — limited write candidate (장기 decision gate)

**목표:** read value와 recovery가 증명된 provider 하나에서 한 가지 R2 write만 검토한다.

**Dependencies:** S6 + S7C; Agent-related write면 S8도 필요.

**Entry gate**

- 실제 반복 사례 ≥3, stable ID/revision, preview diff, idempotency/CAS, reconcile, provider undo 또는 명시적
  recovery가 모두 있다.

**Dashboard deliverable**

- exact account/context/target/diff/scope/irreversibility를 보여주는 foreground approval과 post-write reconcile.

**Stop**

- arbitrary target, non-idempotent retry, rollback 부재, cross-context risk가 있으면 승격하지 않는다.

## 5. cutoff/checkpoint policy

### 5.1 23:30 KST nightly cutoff

매 작업일 **23:30 KST**는 새 scope와 mutation을 멈추는 hard cutoff다. 이는 release date를 뜻하지 않고,
shared `orca/work`에서 작업을 review 가능한 상태로 고정해 다음 날 또는 다음 dispatch가 안전하게 이어받도록
하는 운영 checkpoint다.

- 23:15 KST부터 새 file owner를 잡거나 schema migration, provider apply, restore, default workspace 변경을
  시작하지 않는다.
- 23:30 KST에는 실행 중인 작업을 `accepted`, `stopped`, `rolled-back`, `in-progress-safe` 중 하나로 기록한다.
  `in-progress-safe`는 canonical/working data가 유효하고 partial artifact, owner, exact next action과 rollback이
  기록된 경우에만 허용하며 stage acceptance를 뜻하지 않는다.
- 23:30 이후에는 read-only validation, `git diff --check`, artifact/hash 수집, log/handoff와 already-started safe
  verification만 허용한다. 새 mutation, scope expansion, external write, migration과 dispatch는 다음 작업일로
  넘긴다.
- 이미 시작한 action이 23:30에 외부/authoritative state를 불명확하게 남겼다면 자동 retry하지 않고
  `partial`/`unknown` receipt와 reconcile instruction을 남긴다.
- plaintext Secret 노출, data-loss 진행 또는 actively destructive partial action을 막기 위한 emergency
  containment만 예외다. 예외는 exact action, 이유, 영향, 결과와 후속 review를 checkpoint에 기록하며 새
  feature work로 확장하지 않는다.
- coordinator가 더 이른 dispatch cutoff를 지정하면 더 이른 시각이 우선한다. 이 정책은 늦은 완료를
  성공으로 포장하거나 미완료 stage를 날짜 때문에 close하는 근거가 아니다.

### 5.2 cutoff 단위

각 stage는 다음 artifact를 한 묶음으로 고정해야 한다.

```text
checkpoint ID
  + root/child commit inputs
  + platform/profile
  + schema and migration version
  + validation commands/results
  + canonical data/snapshot manifest hashes
  + known gaps and support tier
  + rollback/disable/rebuild instructions
  + next-stage entry decision
```

- checkpoint는 새로운 schema migration, external write enable, default workspace 변경, backup format 변경 전에
  반드시 만든다.
- incomplete stage는 날짜 때문에 close하지 않는다. accepted, stopped, rolled-back 중 하나를 명시한다.
- 90일 이상 실제 device smoke가 없는 manifest/support tier는 expired로 낮추며 자동 승격하지 않는다.
- cutoff 뒤 발견한 defect는 data loss/security/restore failure이면 현재 stage를 reopen하고, 그 외에는 명시된
  backlog로 다음 stage에 넣는다.
- scope exception은 실제 장애나 반복 사용 evidence와 owner/rollback을 기록한 decision gate가 있어야 한다.

### 5.3 rollback 우선순위

1. provider adapter disable; cached projection은 keep/delete를 사용자가 선택.
2. SQLite projection delete/rebuild.
3. previous schema binary + pre-migration canonical snapshot restore.
4. verified root/child manifest rollback.
5. native terminal에서 Markdown/Git/tmux direct recovery.

## 6. 전체 program stop criteria

다음은 국소 bug가 아니라 roadmap 중단/피벗 조건이다.

- restore drill이 수동 삭제/force Git 없이 반복되지 않는다.
- CLI/Dashboard parity가 구조적으로 불가능해 client별 business rule/state store가 생긴다.
- canonical Markdown과 important receipt가 SQLite 또는 Dashboard 없이는 해석/복구되지 않는다.
- Workbench가 Orca lifecycle을 복제하거나 tmux scraping으로 Agent outcome을 추론해야 한다.
- GitHub→Slack 순서를 건너뛰거나 두 adapter 전에 generic plugin SDK가 필요해진다.
- private GitHub와 OneDrive 역할 분리로도 plaintext Secret, sync conflict 또는 key recovery를 통제하지 못한다.
- personal/work cross-context write, wrong-worktree jump, duplicate Agent launch 또는 destructive unowned mutation이
  한 건이라도 발생한다.

중단 시 최근 accepted checkpoint로 돌아가고, Dashboard와 CLI에는 degraded/support tier와 manual recovery를
동시에 표시한다.

## 7. first implementation slice — S1 v1 compatibility lock

**목표:** 오늘 전달할 첫 bounded slice는 새 IA나 data model이 아니라, 현행 Dashboard의 security/documentation
불일치와 focus 회귀를 닫아 S1 shell을 올릴 수 있는 안정된 v1 기준선을 만드는 것이다.

**Dependencies:** S0 accepted. S1 root verified-manifest, S2 Markdown/SQLite와 S3 ActionPlan/ActionRun에는 의존하지
않으며 그 기능을 선행 구현하지 않는다.

### Backend deliverable — exclusive files

Owner는 backend 한 명이며 다음 file만 수정한다.

- `workbench/internal/dashboard/dashboard.go`: `maxActionBody = 16 << 10`; `*http.MaxBytesError`를 mutation 전
  413/`ACTION_REQUEST_TOO_LARGE`로 normalize한다.
- `workbench/internal/dashboard/dashboard_test.go`: valid-at-limit/one-byte-over-limit, service-not-called,
  unknown/trailing JSON, `/activity`·`/settings`·`/docs`와 query-bearing current-route regression을 추가한다.
- `workbench/docs/dashboard.md`: `update_secret`을 포함한 15-action table과 16 KiB total-body contract를 code와
  일치시킨다.

`internal/cli/dashboard.go`, target route, schema-v2, root setup과 embedded frontend asset은 이 backend slice에서
수정하지 않는다. `/activity`와 `/settings`는 redirect하지 않고 현재 page를 계속 render하며 query는 새
domain meaning으로 해석하지 않는다.

### Frontend deliverable — exclusive files

Owner는 frontend 한 명이며 backend lane과 병렬로 다음 file만 수정한다.

- `workbench/internal/dashboard/assets/app.js`: refresh/action reload 직전 focused control의 stable key를 잡고,
  rerender 뒤 같은 enabled control이 존재하면 복원한다. 대상이 사라졌거나 disabled이면 destructive/인접
  control을 추측하지 않고 현재 route의 visible `h1`로 이동한다.
- `workbench/internal/dashboard/assets/index.html`과 `style.css`: stable focus key와 visible/focusable route `h1`에
  필요한 최소 markup/style만 수정한다. planner가 accepted한 six-area vocabulary는 current route에 label로만
  mapping하고 target route, capability와 state owner는 만들거나 바꾸지 않는다.
- `workbench/internal/dashboard/testdata/focus_test.mjs`: scheduled refresh, action success/failure reload, removed
  target, disabled target과 route fallback을 검증한다. 기존 theme/Guide/context tests를 재사용한다.

Go handler/service/test와 `docs/dashboard.md`는 frontend가 수정하지 않는다. selected-object URL/deep-link,
`/runs`, `/integrations`, `/today`, `/settings` split, common v2 state renderer는 이 slice에 포함하지 않는다.

### Integration order와 test gate

두 lane은 file이 겹치지 않으므로 병렬 작업할 수 있다. final validation owner는 두 lane이 stable해진 뒤 한 번만
통합 검증하며, 실패를 고치기 위해 다른 owner file을 즉시 수정하지 않고 원 owner에게 반환한다.

```bash
cd workbench
go test ./internal/dashboard ./internal/cli
node --check internal/dashboard/assets/app.js
node --test internal/dashboard/testdata/*.mjs
go test ./...
go vet ./...
go build ./cmd/wb
cd ..
git diff --check
```

**Success criteria**

1. 16 KiB 이하의 유효 request는 기존 action contract를 유지하고 16 KiB 초과는 service call/side effect 없이
   413/`ACTION_REQUEST_TOO_LARGE`가 된다.
2. public action table과 executable dispatch/test inventory가 15개로 일치하며 `update_secret` plaintext가
   response, log, snapshot에 나타나지 않는다.
3. `/activity`, `/settings`, `/docs`와 query-bearing request가 기존 content/status를 유지하고 target route는
   새로 생기지 않는다.
4. scheduled refresh와 action reload 뒤 focus가 같은 enabled control 또는 route `h1` 중 하나에 결정적으로
   남고 destructive sibling으로 이동하지 않는다.
5. 위 Go/Node/full-module/static gate가 모두 통과하고 backend/frontend file overlap이 0이다.

**Stop criteria**

- 기존 approved action 중 16 KiB 초과가 필요한 실제 fixture가 나오면 limit change를 멈추고 별도 security
  gate로 보낸다. 임의로 16 MiB를 유지하거나 per-action 예외를 만들지 않는다.
- focus 보존에 browser-owned domain state, selected-object URL grammar, full render rewrite 또는 backend schema가
  필요하면 frontend lane을 중단하고 S2/S3로 defer한다.
- 한 lane이 다른 owner file을 요구하거나 v1 stable error/deep link/security test를 깨면 integration을 멈춘다.
- target navigation, root recovery card, Markdown/SQLite, Orca adapter 또는 Agent mutation으로 scope가 넓어지면
  slice를 reject한다.

**Rollback**

- data migration, provider call과 external side effect가 없으므로 backend와 frontend lane을 독립적으로 S0
  checkpoint content로 되돌릴 수 있다.
- backend rollback은 limit constant/error mapping/test/docs를 함께 되돌려 code/docs drift를 남기지 않는다.
- frontend rollback은 focus helper/markup/test를 함께 되돌리고 current full-rerender behavior를 known gap으로
  복원한다. 한 lane만 accept할 때도 다른 lane의 문서 claim을 미리 바꾸지 않는다.

**23:30 checkpoint**

- 23:15 KST 이후 새 file/scope를 열지 않는다. 각 lane은 changed files, test 결과, known gap과 rollback을 log에
  남긴다.
- 23:30 KST에 둘 다 green이면 `accepted`, 한 lane만 green이면 그 lane만 `accepted`하고 다른 lane은
  `in-progress-safe` 또는 `rolled-back`으로 기록한다. 부분 상태를 S1 완료로 표시하지 않는다.
- 23:30 이후에는 read-only diff/test evidence와 handoff만 허용하며 limit 또는 focus 구현을 새 방식으로
  재시도하지 않는다.

### 7.1 2026-08-10 committed slice acceptance review

**Status: IMPLEMENTATION CHECKPOINT ACCEPTED; release evidence OPEN; full S1 NOT COMPLETE.** Workbench commits
`e80187e`와 `6d7750c`는 linear하고 nested checkout `orca/work`에 commit되어 있으며 root/nested worktree는 이
review 시작 시 clean했다. 두 commit은 data migration, provider write, root recovery 또는 v2 schema를 포함하지
않으므로 독립적으로 검토 가능한 bounded compatibility checkpoint다.

| area | accepted evidence | remaining gate |
|---|---|---|
| scope/ownership | backend commit은 handler/test/public docs 3 files, frontend commit은 embedded assets와 frontend testdata만 변경했다. `navigation_test.mjs` 추가는 frontend-owned fixture 범위이며 six-area label은 current route mapping일 뿐 capability 완료가 아니다. | production source 확장 없음. evidence failure가 없으면 source를 더 수정하지 않는다. |
| 16 KiB pre-mutation | complete body를 `MaxBytesReader`로 먼저 읽고 16,384 bytes는 execute 1, 16,385 bytes는 malformed 여부와 무관하게 execute 0/HTTP 413/fixed copy/empty details다. auth/origin/content-type precedence와 unknown/trailing rejection을 보존했다. | none for code gate. 실제 code 이름인 `ACTION_REQUEST_TOO_LARGE`가 planner spec/backend/frontend contract의 canonical v1 code이며 이전 PM draft의 `ACTION_BODY_TOO_LARGE`를 이 review에서 정정했다. |
| 15 actions/Secret | executable 15 request shape를 각각 통과시키고 public table에 `update_secret`을 추가했다. Secret replacement는 write-only이고 oversize response가 body/decoder sentinel을 echo하지 않는다. | validation owner가 hostile server `message/details`, path/token/Secret sentinel이 DOM/accessibility tree/title에 0임을 real browser에서 증명한다. existing scheduler/diagnostic display의 S2/S3 threat review는 이 slice가 새로 해결했다고 주장하지 않는다. |
| routes/deep links | current page와 Guide aliases의 GET/HEAD는 200, `/today`, `/inbox`, `/runs`, `/integrations`, v2는 404다. UI target label은 `/`, `/projects`, `/activity`, `/settings`, `/system`만 사용하고 Inbox는 non-navigating unavailable control이다. | `/activity?source=bookmark#task-detail`와 `/settings?source=bookmark#secrets`의 path/search/hash 보존은 browser gate에서 확인한다. selected-object URL grammar는 여전히 S2/S3 deferred다. |
| focus/error UI | exact id/existing non-secret data/form identity만 capture하고 same connected/enabled/visible control로 restore한다. missing/disabled/hidden/`aria-disabled` target은 visible route `h1`만 선택한다. generic failure UI는 raw server message/details 대신 bounded code와 fixed copy를 쓴다. Node 20/20이 helper와 manual/timer/action wiring을 검증했다. | 실제 DOM replacement, keyboard order, focus ring, scroll retention과 concurrent refresh/action behavior는 real browser evidence 전에는 release-pass로 계산하지 않는다. |
| validation/rollback | PM rerun에서 focused Go, `go test ./...`, `go vet ./...`, `go build ./cmd/wb`, JS syntax, Node 20/20와 root/nested `git diff --check`가 모두 통과했다. | rollback은 data 복구 없이 `6d7750c` frontend를 먼저, 필요하면 `e80187e` backend를 뒤에 revert하는 commit-level 경로다. 실제 rollback 수행은 failure/decision gate가 있을 때 owner가 한다. |

따라서 code checkpoint는 accept하지만 Dashboard release acceptance와 S1 stage completion은 보류한다. 23:30 전에
아래 browser evidence가 green이면 slice를 `accepted`로 승격한다. 완료되지 않거나 재현 가능한 defect가 있으면
committed pair를 `in-progress-safe`로 기록하고 새 mutation/retry를 시작하지 않는다. security leak, wrong focus로
destructive sibling 선택, current route break가 나오면 release를 stop하고 해당 lane만 rollback/fix gate로 돌린다.

### 7.2 exact next slice — S1 real-browser acceptance closure

이 다음 slice는 **product code를 기본적으로 수정하지 않는 validation-only gate**다. dependencies는 `e80187e`와
`6d7750c`, accepted v1 fixture와 local disposable Dashboard instance다.

- **Validation owner:** Chromium 계열 real browser에서 current five routes+Guide, query/hash 두 bookmark, manual/timer/
  action success/failure focus matrix, keyboard traversal, 360/768/1280px, 200% zoom, light/dark/system, visible focus,
  44px target, 16px form text, body overflow/scroll retention을 evidence로 남긴다. hostile 413/snapshot envelope의
  Unix/Windows path, token, Secret, command/stdout/stderr sentinel이 visible DOM, accessibility tree와 title에 0인지
  확인한다.
- **Frontend owner:** browser evidence가 focus/navigation/render defect를 재현할 때만 embedded assets와 frontend
  browser fixture를 수정한다. route/schema/backend file은 수정하지 않는다.
- **Backend owner:** 413 pre-execution, route status 또는 server envelope redaction defect가 재현될 때만 handler/
  test/docs lane을 수정한다. target route나 v2 field를 만들지 않는다.
- **Planner owner:** recorded screenshot/accessibility results를 Dashboard acceptance matrix에 대조하고 label과
  capability 완료를 분리한다. PM은 evidence를 판정하고 full S1로 잘못 승격하지 않는다.

**Success:** required browser matrix 전부 pass, path/search/hash byte preservation, body/destructive-neighbor focus 0,
sentinel leak 0이고 existing Go/Node/full gates가 다시 green이다. **Stop:** harness/dependency 도입이 product code,
network install, S2/S3 state/route를 요구하거나 destructive/current-authority mutation 없이는 fixture를 만들 수 없으면
중단하고 validation-infrastructure decision gate를 연다. 23:15에는 새 case/fix를 freeze하고 23:30에 green이면
slice `accepted`, 아니면 `in-progress-safe` 또는 lane rollback과 exact failed evidence를 기록한다.

이 browser closure가 accepted된 뒤의 implementation 순서는 S1 root profile/verified-manifest/recovery, S2 canonical
schema/journal/projection, S3 shared application service다. browser closure가 늦어져도 S1 root의 isolated planning은
가능하지만 Dashboard release 또는 S1 completion을 주장할 수 없다. S2 schema contract가 accepted되기 전
backend/frontend가 concrete v2 field를 각자 고정하지 않으며, S1 recovery와 S2 data gate 전에는 GitHub adapter
또는 Orca E1을 시작하지 않는다.
