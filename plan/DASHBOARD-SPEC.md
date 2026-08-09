# Dashboard 제품·UX 명세

> 상태: **Phase 0 결정 명세 — 구현 전**
> 기준일: 2026-08-10
> 제품 방향: [PRODUCT-PLAN.md](PRODUCT-PLAN.md)
> 현재 구현 계약: [`workbench/docs/dashboard.md`](../workbench/docs/dashboard.md)

## 1. 목적과 범위

Dashboard는 폐기하거나 새 애플리케이션으로 대체하지 않는다. 현재의 loopback operations console을
재사용해 **오늘의 판단, 수집, 프로젝트 복귀, 실행 검토, 연동 상태와 복구**를 잇는 Workbench Core의
시각 client로 발전시킨다. `wb` CLI는 같은 Core의 terminal-first client이며 Dashboard와 동등한 기능
계약을 사용한다. 한쪽에서만 존재하는 사용자 상태나 mutation 규칙을 만들지 않는다.

이 문서는 목표 정보 구조, 화면 상태, 반응형·접근성 동작, Core/API/action 경계와 단계별 인수 기준을
정한다. route 이름과 schema 예시는 구현 계획을 위한 target contract이며, 현재 구현된 endpoint와 action은
별도로 표시한다. frontend/backend 구현 파일을 이 문서만으로 변경했다고 간주하지 않는다.

### 고정 불변식

1. Dashboard와 `wb`는 **Workbench Core의 client**이며 두 번째 state owner가 아니다.
2. 사용자 작성 task·note·decision은 Markdown이 canonical이고 SQLite는 삭제 후 재구축 가능한 projection이다.
3. 외부 원문은 provider가 소유하며 Core는 stable reference, 허용된 cached metadata, provenance와 cursor만 가진다.
4. Orca가 기본 terminal workspace와 Agent runtime이다. Workbench는 Orca lifecycle을 복제하지 않는다.
5. Windows Terminal과 iTerm2는 각 OS의 native fallback, tmux는 Orca worktree별 human-work partition,
   cmux는 선택적 macOS client다.
6. 모든 write는 typed mutation, 직전 대상 재검증, 위험 표시, preview/승인, journal과 복구 결과를 갖는다.
7. arbitrary shell, prompt, path, argv, environment, force/delete 우회 필드는 Dashboard API에 두지 않는다.
8. file/Git 다음 외부 connector는 GitHub read-only, 그 다음은 같은 계약을 재사용하는 Slack read-only다.
9. private GitHub는 Markdown·설정 history, OneDrive는 Secret을 제외한 암호화 snapshot·attachment·runtime
   backup을 담당한다. 같은 working tree를 둘이 동시에 동기화하지 않는다.
10. Dashboard, Orca 또는 외부 service가 없어도 `wb`, Markdown, Git과 native terminal fallback으로 읽기와
    복구가 가능해야 한다.

## 2. Surface와 실행 위치

| Surface | 기본 역할 | 실행·소유권 계약 |
|---|---|---|
| Dashboard | Today/review 권장 UI, triage, health, 제한된 typed action | Core API만 사용; browser-local theme 외 상태 소유 금지 |
| `wb` CLI | capture/action/resume의 terminal-first 경로, 장애 시 복구 | Dashboard와 같은 Core service·schema·policy 사용 |
| Orca | 기본 workspace, worktree·terminal·Agent·Run/Task/Dispatch lifecycle | provider runtime의 유일한 owner; Core에는 opaque ref와 관찰 시각만 투영 |
| tmux | Orca worktree마다 사람의 shell/editor 작업을 분리·복귀 | human work partition; Agent를 tmux registry로 재소유하지 않음 |
| Windows Terminal | Windows/WSL에서 Orca가 없거나 사용할 수 없을 때 native fallback | native tab/pane identity가 불안정하면 launch-only로 표시 |
| iTerm2 | macOS에서 Orca가 없거나 사용할 수 없을 때 native fallback | Phase 0 결정이며 adapter 구현·검증 전에는 unavailable로 표시 |
| cmux | macOS의 선택적 client/open target | 기본값이나 필수 dependency가 아니며 실패 시 iTerm2/CLI 경로 유지 |

기본 project resume 순서는 `Orca → OS native fallback(Windows Terminal/iTerm2) → current shell`이다.
tmux는 이 순서와 경쟁하는 별도 workspace backend가 아니라, Orca worktree 내부에서 사람의 장기 shell/editor
맥락을 나누는 partition이다. Agents는 Orca terminal에서 직접 실행한다. Orca가 없는 fallback 실행은
`observed/unmanaged`로만 투영하며 Workbench가 stop 권한을 추측하지 않는다.

## 3. 목표 정보 구조

### 전역 navigation

| 영역 | 핵심 질문 | 기본 내용 | 주요 action |
|---|---|---|---|
| **Today** | 지금 무엇을 해야 하고 무엇이 깨졌나 | due/next, 미분류 수, resume, failed/partial run, stale integration | task 열기, work location resume, review 시작 |
| **Inbox** | 새 입력을 어떻게 처리할까 | source/account/context, received time, 원문 ref, 중복 후보, 분류 상태 | project 연결, next action, defer/reference/archive |
| **Projects** | 결과·다음 행동·실행 위치는 어디인가 | task, decision/ref, repo, Git, Orca worktree, human tmux partition | project resume, task 편집, 안전한 work location 열기 |
| **Runs & Agents** | 무엇을 실행했고 어디까지 됐나 | run/attempt/checkpoint/artifact/outcome, managed/observed Agent | review packet, jump, 허용된 launch, recovery 확인 |
| **Integrations** | 무엇과 어떤 권한으로 연결됐나 | adapter capability, account/context, scope, cursor, sync health | sync, reconnect, disable, export/cache 선택 |
| **System & Recovery** | 설치와 데이터가 복구 가능한가 | profile, Doctor, projection rebuild, backup, restore, fallback | validate, backup, restore preview, recovery guide |

Dashboard의 primary navigation은 위 여섯 영역으로 제한한다. `Areas`, `Library`, `Settings`, `Activity`는
사라지는 데이터 도메인이 아니라 다음처럼 흡수된다.

- Area/context policy와 account 선택은 Projects와 Integrations의 filter/detail로 둔다.
- Library의 note/decision/external ref는 global search와 Project detail에서 연다.
- 현재 Settings는 Integrations와 System & Recovery로 나눈다.
- 현재 Activity는 Runs & Agents의 journal과 Today의 attention projection으로 이동한다.
- Guide는 도움말 entry로 유지하되 primary product area와 구분한다.

### route target과 현재 route의 이행

| Target route | 초기 source | 호환 정책 |
|---|---|---|
| `/` 또는 `/today` | 현재 `/` Overview | `/`는 Today가 되며 `/today` alias 허용 |
| `/inbox` | 신규 Core query | schema gate 전에는 명확한 준비 중 empty state |
| `/projects` | 현재 `/projects` | 안전 계약과 deep link를 유지하며 확장 |
| `/runs` | 현재 `/activity` + project Task history | `/activity`는 최소 한 release 동안 redirect/alias |
| `/integrations` | 현재 `/settings` 일부 | profile/Secret owner를 분리한 뒤 이행 |
| `/system` | 현재 `/system` + `/settings` 일부 | label을 System & Recovery로 확장 |
| `/guide` | 현재 Guide | embedded/offline 동작 유지 |

## 4. 화면 명세

### Today

상단은 `generated_at`, active personal/work context filter, stale source 수와 수동 refresh를 보인다. 본문 순서는
`Next actions → Resume → Needs review → Sync/health`다. task와 run을 별도 복제하지 않고 Core query가 만든
projection을 렌더링한다.

- Next actions: due/start/blocked reason/done condition을 보이며 priority 숫자만으로 정렬하지 않는다.
- Resume: project, branch/worktree, human tmux partition 또는 Orca reference, `observed_at`, jump 가능 여부를 보인다.
- Needs review: unclassified Inbox, partial/failed/unknown run, expired credential, stale adapter를 원인별로 나눈다.
- cached 외부 data는 마지막 성공 시각을 붙이고 local Markdown/Git 항목과 시각적으로 구분한다.

### Inbox

목록과 detail의 triage 화면이다. 각 항목은 `id`, source kind/ID, source account, context, received time,
privacy, immutable original reference, cached title/summary, duplicate evidence와 classification을 표시한다.

- 분류하지 않음을 유효한 상태로 허용한다.
- bulk action은 같은 context와 같은 action type에만 허용하고 결과 preview를 먼저 보인다.
- 개인/업무 destination이 source policy와 다르면 write를 fail-closed하고 두 경계를 함께 표시한다.
- provider가 unavailable이어도 local/manual/file item 분류는 계속된다.

### Projects

desktop에서는 project list, project workspace, 선택 detail의 기존 3-column 패턴을 재사용한다. project header는
outcome, next action, done condition과 canonical repo를 먼저 보여주고 Git/refs/task/work location을 아래에 둔다.

- 기본 Resume은 Orca worktree를 canonical repo/path/branch로 재검증해 연다.
- human tmux partition은 연결된 Orca worktree 아래에 표시한다.
- Windows Terminal/iTerm2 fallback은 선택 이유와 capability를 표시하고 자동 이중 launch하지 않는다.
- 외부/dirty/prunable worktree는 관찰 상태와 허용 action을 구분한다.
- note/decision edit는 canonical Markdown revision을 대상으로 하며 projection row 직접 편집은 금지한다.

### Runs & Agents

Run과 provider Agent를 억지로 하나의 lifecycle로 합치지 않고, 관계를 보여주는 review surface로 둔다.

- Run: recipe/action, attempt, input hash, risk, approval, checkpoint, artifact pointer, outcome과 recovery instruction.
- Agent: provider, provider-owned stable reference, project/worktree, ownership, confidence, observed time, result pointer.
- 상태는 `received/staged/applied/reviewed`와 `blocked/retryable/partial/unknown`을 보존한다.
- Orca Run/Task/Dispatch는 Orca가 소유한다. Core의 장기 Task/Run과 ID namespace를 혼용하지 않는다.
- jump는 provider identity와 target을 fresh-read한 뒤 실행한다. stop/remove는 안정된 ownership 계약과 별도
  phase 승인 전에는 제공하지 않는다.
- review packet은 요구사항 ref, diff/artifact, test 결과, 미결 항목을 연결하되 transcript 전문은 opt-in이다.

### Integrations

adapter별로 provider, capability(read/write), account/context, auth reference availability, granted scope, cursor,
last attempt/success, stale reason과 next retry를 표시한다. Secret 값과 raw token은 표시하지 않는다.

- Phase 1은 file/Git health와 provenance만 지원한다.
- GitHub read-only를 첫 외부 connector로, 계약 재사용 gate를 통과한 뒤 Slack read-only를 추가한다.
- disconnect는 remote data를 지우는 action과 분리한다. cached metadata preserve/delete와 export를 명시적으로 고른다.
- sync 실패는 전역 Dashboard 실패가 아니라 해당 adapter의 retryable/blocked/partial 상태다.

### System & Recovery

active profile, platform support evidence, Workbench/Orca/native fallback capability, Doctor, projection 상태,
backup history와 restore drill 결과를 한곳에서 보여준다.

- Markdown canonical store가 readable이면 SQLite projection 장애 중에도 read-only 목록과 rebuild action을 제공한다.
- rebuild는 canonical files를 바꾸지 않고 새 DB를 만든 뒤 schema/count 검증 후 교체한다.
- restore는 source, captured time, encryption/unlock availability, included/excluded 범위와 destination을 preview한다.
- GitHub history와 OneDrive encrypted snapshot의 역할, 마지막 검증과 충돌 경고를 별도 카드로 표시한다.
- 설치/repair shell command는 정보로만 제공하며 Dashboard가 임의 실행하지 않는다.

## 5. 공통 화면 상태

모든 area는 다음 상태를 독립적으로 표현한다. 전체 화면 spinner 하나로 정상 local data까지 가리지 않는다.

| 상태 | 표시 | 허용 동작 |
|---|---|---|
| initial loading | skeleton 또는 명시적 loading text, 영역 이름 유지 | navigation, Guide |
| refreshing | 기존 결과 유지 + 갱신 시각/진행 표시 | 안전한 local read; 중복 mutation 방지 |
| empty | 왜 비었는지와 첫 local action | capture/open guide 등 한 개의 next step |
| stale | last successful/attempt time, 원인, 영향 범위 | local action 지속, manual sync |
| partial | 성공한 자산, 실패한 단계, recovery instruction | review/reconcile; 자동 write retry 금지 |
| retryable | next retry와 idempotency 근거 | read/idempotent retry만 |
| blocked | auth/policy/conflict reason과 owner | reconnect, policy review, manual merge |
| unknown/observed | evidence, confidence, observed time | 재관찰/jump만; mutation 금지 |
| unavailable/unsupported | platform/capability reason과 fallback | CLI/native fallback |
| offline/provider down | local cached/canonical data 유지 | local capture, Markdown/Git 작업 |
| permission denied | requested/effective scope와 target | credential/policy 변경 경로; 자동 확대 금지 |
| action success | non-blocking notice + fresh snapshot/journal ref | 결과/detail 열기 |
| action failure | stable error code, survivor, recovery | 안전한 재시도 또는 terminal 명령 |

마지막 정상 snapshot을 보존할 때는 그 시각과 stale badge를 반드시 붙인다. 빈 결과와 load 실패를 같은 UI로
표현하지 않는다.

## 6. 반응형 동작

### Wide desktop (`≥1180px`)

- persistent global nav + area filter rail + main list/workspace + optional detail의 최대 3-column.
- detail이 열려도 primary action과 ownership/risk label이 가려지지 않는다.
- dense tables는 column priority를 사용하고 horizontal page scroll을 만들지 않는다.

### Compact desktop/tablet (`720–1179px`)

- global nav는 가로 scroll 또는 compact menu, filter rail은 drawer/disclosure로 전환한다.
- main과 detail의 2-column을 우선하며 detail은 명시적으로 닫을 수 있다.
- hover action은 항상 focus/tap으로도 발견할 수 있다.

### Narrow (`<720px`)

- 단일 column, 순서 `page title/status → primary action → filters → content → detail`.
- 표는 label/value card로 변환하며 ID, status, next action, recovery를 숨기지 않는다.
- destructive/approval control은 sticky하지 않고 대상 요약과 같은 flow에 둔다.
- 최소 44×44 CSS px touch target, viewport 안 dialog, body text 16px 이상을 목표로 한다.

모든 breakpoint에서 keyboard tab order는 DOM의 의미 순서를 따르고 resize 후 focus를 잃지 않는다. 출력이 긴
ID/path는 복사 가능하게 하고 시각적으로 wrap/truncate하되 accessible name에는 전체 값을 보존한다.

## 7. 접근성 계약

- 목표는 WCAG 2.2 AA다. 색만으로 managed/observed, stale/error, personal/work를 구분하지 않는다.
- 각 page는 하나의 `h1`, 논리적 heading 순서, `header/nav/main/aside` landmark와 main skip link를 가진다.
- active navigation은 `aria-current="page"`, 선택 row는 `aria-selected` 또는 적합한 native pattern을 사용한다.
- update notice는 `role=status`/polite, destructive failure는 사용 흐름을 막지 않는 범위에서 alert를 사용한다.
- dialog는 이름, initial focus, focus trap, Escape와 호출 control로의 focus 복귀를 제공한다.
- form error는 field와 programmatically 연결하고 첫 error로 focus summary를 제공한다.
- status refresh가 사용자의 현재 focus나 screen-reader reading 위치를 강제로 이동하지 않는다.
- `prefers-reduced-motion`, system/light/dark theme, 200% text zoom과 high-contrast focus indicator를 지원한다.
- chart만으로 정보를 제공하지 않고 같은 사실을 text/table로 제공한다.

## 8. Core·API 계약

### client parity와 versioning

Dashboard와 `wb`는 같은 application service를 호출한다. HTTP handler와 CLI command가 각자 Markdown,
SQLite 또는 provider registry를 해석하지 않는다. Core query/action은 versioned request/response와 stable error
code를 가지며 JSON은 unknown field와 trailing value를 거부한다.

현재 `GET /api/v1/snapshot`과 `POST /api/v1/actions`는 호환 baseline이다. 이행 중에는 하나의 거대 snapshot을
유지할 수 있지만 target은 area query가 공통 envelope를 쓰는 것이다.

```json
{
  "schema_version": 2,
  "generated_at": "RFC3339",
  "data_revision": "opaque",
  "freshness": {"state": "fresh|stale|partial", "observed_at": "RFC3339"},
  "capabilities": [],
  "data": {},
  "warnings": []
}
```

권장 query는 `/api/v2/today`, `/inbox`, `/projects`, `/runs`, `/integrations`, `/system`이며 filter/cursor는
allowlist된 typed field만 받는다. pagination cursor는 opaque하고 provider cursor를 browser에 그대로 노출하지
않는다. 모든 response는 Secret plaintext, prompt/terminal transcript, raw auth reference, 불필요한 filesystem
path를 제외한다.

### no-second-state-owner rule

| Domain | canonical owner | Core projection | 금지 |
|---|---|---|---|
| task/note/decision | Markdown file | search/index/link row | SQLite row만 수정, browser draft를 별도 truth로 sync |
| project config/policy | versioned Core config/Markdown | effective view | UI 전용 registry |
| Git/worktree | Git porcelain/repository | cached status + observed time | projection만 보고 delete |
| Orca runtime | Orca | opaque ref, capability, observed time, result pointer | Run/Dispatch lifecycle 복제·추측 |
| human tmux partition | tmux + explicit Core link | pane/session evidence | title/process-name 기반 ownership 부여 |
| external object | GitHub/Slack 등 provider | stable ref + allowlisted cache | remote 원문 자동 복제·last-write-wins |
| authored history | private GitHub Git repo | sync health | OneDrive가 같은 working tree sync |
| backup snapshot | encrypted OneDrive archive | catalog/restore evidence | plaintext Secret 포함, backup을 live state로 편집 |
| theme | browser localStorage | 없음 | Core config나 cross-device state로 승격 |

SQLite가 없어지거나 손상돼도 canonical Markdown과 provider references로 재구축할 수 있어야 한다. projection
schema migration은 dry-run, backup, count/reference validation과 last-known-good 복구를 제공한다.

## 9. typed mutation 안전 계약

모든 mutation request는 아래 공통 필드를 가진다.

```json
{
  "action": "stable_action_id",
  "target": {"type": "task", "id": "stable-id"},
  "expected_revision": "opaque",
  "idempotency_key": "client-generated-opaque",
  "input": {},
  "preview_token": "required-for-apply-when-risk-is-write-or-destructive"
}
```

Core는 action별 input schema와 capability를 소유한다. `preview` 결과는 canonical target, source/destination
context, requested/effective permission, side effects, risk(`read|write|destructive`), backup/checkpoint, expiry와
승인 문구를 포함한다. apply는 preview와 같은 target revision/policy일 때만 허용하며 달라지면
`STALE_PREVIEW`로 거부한다.

### 최소 action family

| Area | typed action | 안전 경계 |
|---|---|---|
| Today/Projects | `resume_project`, `open_work_location` | canonical repo/worktree/provider identity fresh-read; 한 target만 launch |
| Inbox | `classify_inbox_item`, `link_inbox_project`, `archive_inbox_item` | source/destination context, revision, duplicate set 확인 |
| Projects | `update_task`, `update_decision` | canonical Markdown revision 대상, atomic file write + projection refresh |
| Runs & Agents | `jump_agent`, `start_agent`(E2 이후), `review_run` | Orca capability/effective permission; result pointer만 Core에 기록 |
| Integrations | `sync_adapter`, `disconnect_adapter`, `clear_adapter_cache` | account/scope/cursor 구분; remote delete와 분리 |
| System & Recovery | `rebuild_projection`, `create_backup`, `restore_backup` | canonical store 불변, backup/schema 검증, destination preview |

현재 v1 action(`open_project`, `attach/adopt/stop_session`, environment/profile/Secret mutation, Agent/task jump/stop,
history clear, workflow run)은 즉시 제거하지 않는다. target action으로 mapping될 때까지 현재 owner revalidation,
token/origin/body limit, backup, allowlisted argv와 error contract를 유지한다. 특히 현재 제공되는 destructive
action을 새 화면에 자동 노출하지 않으며 각 action의 제품 phase와 ownership gate를 다시 통과시킨다.

### outcome과 retry

- 공통 결과: `succeeded`, `blocked`, `retryable`, `partial`, `unknown`; 단일 `failed`만 반환하지 않는다.
- partial은 surviving resource/artifact, completed step, failed step와 recovery instruction을 필수로 가진다.
- read/idempotent action만 bounded auto-retry한다. write timeout은 provider/canonical state를 재조회한다.
- journal은 action ID, target, policy/revision, 승인, 시각, outcome, artifact/recovery pointer를 저장하며 Secret,
  prompt와 command output 전문은 저장하지 않는다.
- HTTP는 loopback, same-origin per-process token, restrictive CSP/no-CORS/no-store와 bounded request를 유지한다.

## 10. 단계별 deliverable과 acceptance test

### Phase 0 — 결정·계약 등록

Deliverable:

- 이 명세와 제품 계획에 목표 IA, surface/runtime ownership, data/backup split을 등록한다.
- 현재 v1 Dashboard route/action과 target contract의 compatibility map을 확정한다.
- Markdown 최소 schema, Core query/action interface와 v2 envelope의 backend RFC를 후속 작업으로 만든다.

Acceptance:

1. 문서에서 Dashboard와 CLI가 같은 Core client이고 state owner가 아님을 모순 없이 설명한다.
2. Orca default, native fallback, worktree별 human tmux, direct Orca Agent, optional cmux가 한 표에 명시된다.
3. 현재 구현 기능과 future target을 혼동하지 않고 각 단계가 frontend/backend 작업으로 분리된다.

### Phase 1 — Core parity와 compatibility shell

Deliverable:

- 기존 Overview/Projects/Activity/Settings/System data를 새 nav shell에 loss 없이 배치한다.
- CLI와 Dashboard가 같은 query/action service와 stable errors를 사용한다.
- loading/empty/stale/partial/unavailable 상태 component와 route alias를 만든다.

Acceptance:

1. current v1 handler/security/action tests가 유지되고 `/activity` deep link가 유효하다.
2. 같은 fixture에서 `wb --json`과 Dashboard query의 domain 결과/owner/capability가 일치한다.
3. JS 없이 Guide/heading/navigation 의미 구조가 읽히며 keyboard-only로 모든 route와 visible action에 접근한다.
4. 360px, 768px, 1280px에서 content loss, body horizontal overflow와 focus loss가 없다.

### Phase 2 — 30일 local closed loop

Deliverable:

- canonical Markdown + rebuildable SQLite로 Context, InboxItem, Project, Task, ExternalRef, WorkLocation, Run을 구현한다.
- file/stdin capture → Inbox triage → Today → Orca/native resume → Run review를 연결한다.
- System & Recovery에 projection rebuild와 검증된 backup/restore preview를 제공한다.

Acceptance:

1. offline capture가 10초 이내 저장되고 Dashboard와 CLI 양쪽에 같은 stable ID/provenance로 나타난다.
2. SQLite를 제거한 fixture에서 Markdown만으로 rebuild한 결과가 stable ID/reference/count를 보존한다.
3. personal→work 또는 work→personal mismatch write가 UI와 CLI 모두 같은 code로 fail-closed한다.
4. Orca unavailable fixture에서 Windows Terminal/iTerm2(지원 OS) 또는 shell fallback을 명시적으로 선택할 수 있고
   중복 launch가 없다.
5. partial action fixture가 surviving asset와 recovery instruction을 표시하며 자동 destructive retry를 하지 않는다.
6. backup fixture에는 plaintext Secret이 없고 실제 restore drill이 schema validation을 통과한다.

### Phase 3 — external read connector

Deliverable:

- GitHub read-only metadata adapter를 먼저 추가하고 provenance/cursor/health/reconcile/disconnect/export를 검증한다.
- 같은 계약 재사용 gate를 통과한 후 Slack read-only intake를 추가한다.

Acceptance:

1. duplicate/out-of-order/missed event fixture가 immutable source ID와 cursor reconcile로 원문 ref를 잃지 않는다.
2. stale/auth/rate-limit은 해당 integration만 degrade하고 local Today/Inbox/Projects는 계속 동작한다.
3. account/context와 granted scope가 모든 item/action preview에 보이고 Secret/token은 snapshot/journal/DOM에 없다.
4. GitHub 계약을 예외 분기 없이 재사용하지 못하면 Slack 단계는 시작하지 않는다.

### Phase 4 — controlled execution과 제한 write

Deliverable:

- Orca E0/E1 gate 뒤 safe-profile Agent launch와 result pointer 회수를 제공한다.
- 실제 반복 증거가 있는 typed integration write 하나만 preview/apply/reconcile/rollback으로 승격한다.

Acceptance:

1. 10개 non-destructive Agent task에서 target worktree/effective permission 오류와 duplicate launch가 0건이다.
2. preview 이후 target revision/policy 변경은 apply를 `STALE_PREVIEW`로 거부한다.
3. timeout 이후 provider state reconcile 전 write를 재시도하지 않는다.
4. Orca lifecycle을 Core DB가 소유하지 않고 Orca 부재 시 기존 local recovery가 100% 유지된다.

## 11. 출시 전 공통 검증

- unit/contract: Core owner, schema/version, unknown field, revision/idempotency, redaction, error/outcome fixture.
- browser: keyboard, screen reader landmark/name, theme/contrast, reduced motion, zoom 200%, responsive screenshots.
- security: loopback/origin/token/CSP/body limit, argument array, canonical target revalidation, Secret/prompt/path redaction.
- recovery: corrupt projection, provider outage, expired auth, partial launch, interrupted restore와 last-known-good rollback.
- parity: 대표 capture, triage, resume, review, rebuild를 CLI와 Dashboard에서 교차 실행해 같은 canonical 결과 확인.

Dashboard의 성공은 화면 수가 아니라 4주 자발적 Today/review 사용, capture/복귀 시간, provenance 보존,
잘못된 context write와 복구 불가능한 partial run이 줄어드는지로 판단한다. 자발적 사용률이 50% 미만이거나
fallback이 20%를 넘으면 Dashboard를 operations 보조 UI로 유지하되 CLI/Core 계약과 복구 경로는 그대로 둔다.
