# Dashboard 제품·UX 명세

> 상태: **Phase 0 결정 명세 — 구현 전**
> 기준일: 2026-08-10
> 제품 방향: [PRODUCT-PLAN.md](PRODUCT-PLAN.md)
> 목표 구조·stage: [ARCHITECTURE.md](ARCHITECTURE.md) · [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md)
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
2. 사용자 작성 task·note·decision과 중요한 receipt는 Markdown/portable journal이 canonical이고, SQLite는
   provider에서 다시 받는 O2 cache와 C1–C3/O1/O2에서 재생성하는 O3 derived projection만 가진다.
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
| Dashboard | Today/review 권장 UI, triage, health, 제한된 typed action | client-neutral application service만 사용; browser-local theme 외 상태 소유 금지 |
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
| `/` | 현재 `/` Overview | canonical Today entry로 유지; 현재 data만 표시 |
| `/today` | 신규 alias | S2 Today read capability acceptance 뒤 같은 view를 server-render하는 alias; 그 전에는 만들지 않음 |
| `/inbox` | 신규 Core query | S2 acceptance 전에는 404+nav unavailable; 404를 empty Inbox로 표현하지 않음 |
| `/projects` | 현재 `/projects` | 안전 계약과 deep link를 유지하며 확장 |
| `/runs` | 현재 `/activity` + project Task history | S3 acceptance 뒤 canonical; `/activity`는 rendered compatibility alias로 유지 |
| `/integrations` | 현재 `/settings` 일부 | profile/Secret owner를 분리한 뒤 이행 |
| `/system` | 현재 `/system` + `/settings` 일부 | label을 System & Recovery로 확장 |
| `/guide` | 현재 Guide | embedded/offline 동작 유지 |

S1의 smallest slice는 새 route를 추가하지 않는다. target label은 현재 route에 mapping하고 Inbox는 focus 가능한
`준비 중 · S2 필요` 항목으로 표시하되 link나 empty data를 만들지 않는다. `/activity`와 `/settings`는 query와
fragment를 버릴 수 있는 redirect 대신 같은 route를 render한다. `/runs`가 생긴 뒤에도 `/activity`는 최소 한
release 유지하고, 30일 explicit compatibility observation에서 사용 0이 증명되지 않으면 제거하지 않는다.
`/settings`는 Integrations와 System & Recovery로 연결하는 compatibility index이므로 한쪽으로 redirect하지
않는다. Project/Task/Run ID의 URL grammar는 S2 identity와 S3 application-service acceptance 전에는 정의하지 않는다.

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

- S2/S3은 file/Git health와 provenance만 지원하고 S5 전에는 external provider를 노출하지 않는다.
- GitHub read-only를 첫 외부 connector로, 계약 재사용 gate를 통과한 뒤 Slack read-only를 추가한다.
- disconnect는 remote data를 지우는 action과 분리한다. cached metadata preserve/delete와 export를 명시적으로 고른다.
- sync 실패는 전역 Dashboard 실패가 아니라 해당 adapter의 retryable/blocked/partial 상태다.

### System & Recovery

active profile, platform support evidence, Workbench/Orca/native fallback capability, Doctor, projection 상태,
backup history와 restore drill 결과를 한곳에서 보여준다.

- Markdown canonical store가 readable이면 SQLite projection 장애 중에도 read-only 목록과 rebuild action을 제공한다.
- rebuild는 canonical files를 바꾸지 않고 새 DB를 만든 뒤 schema/count 검증 후 교체한다.
- restore는 source, captured time, encryption/unlock availability, included/excluded 범위와 destination을 같은
  Core plan으로 preview한다. 안전한 completion을 보장할 수 있는 platform에서는 foreground approval 뒤 같은
  action을 실행하고, 그렇지 않으면 같은 `action_id`의 exact CLI handoff를 제공한다.
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
유지할 수 있지만 target은 area query가 공통 envelope를 쓰는 것이다. 아래 v2 이름과 field는 architecture를
설명하는 **비규범 예시**이며 S2 schema와 S3 application-service contract가 acceptance를 통과하기 전에
frontend와 backend가 서로 독립적으로 고정하지 않는다.

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
| project config/policy | versioned TOML/JSON/Markdown(C3) | effective view | UI 전용 registry |
| important receipt | append-oriented Markdown/portable journal(C2) | searchable receipt view | SQLite/activity history에만 approval·plan hash·checkpoint 저장 |
| pending mutation/fencing | transactional portable journal(O1) + C2 receipt link | pending/reconcile view | rebuild 가능한 cache로 오분류 |
| Git/worktree | Git porcelain/repository | cached status + observed time | projection만 보고 delete |
| Orca runtime | Orca | opaque ref, capability, observed time, result pointer | Run/Dispatch lifecycle 복제·추측 |
| human tmux partition | tmux + explicit Core link | pane/session evidence | title/process-name 기반 ownership 부여 |
| external object | GitHub/Slack 등 provider | stable ref + allowlisted cache | remote 원문 자동 복제·last-write-wins |
| authored history | private GitHub Git repo | sync health | OneDrive가 같은 working tree sync |
| backup snapshot | encrypted OneDrive archive | catalog/restore evidence | plaintext Secret 포함, backup을 live state로 편집 |
| theme | browser localStorage | 없음 | Core config나 cross-device state로 승격 |

SQLite가 없어지거나 손상돼도 C1–C3, O1 durable journal과 O2 provider facts로 O2 cache/O3 projection을
재구축할 수 있어야 한다. C1은 human/LLM content, C2는 important receipt, C3는 portable declaration, O1은 authoritative
local operational state, O2는 provider-authoritative projection, O3는 derived cache다. Secret은 어느 class의
본문에도 넣지 않는다. projection schema migration은 dry-run, backup, count/reference/receipt validation과
last-known-good 복구를 제공한다.

## 9. typed mutation 안전 계약

모든 mutation은 Core가 `ActionPlan`을 만들고 두 client가 같은 `ActionRun`으로 apply/reconcile하는 흐름을
사용한다. 아래는 개념 예시이며 구체 field 이름은 S3 contract가 소유한다.

```json
{
  "action_type": "stable_action_type",
  "action_id": "core-issued-opaque-id",
  "target": {"type": "task", "id": "stable-id"},
  "expected_revision": "opaque",
  "idempotency_key": "client-generated-opaque",
  "plan_hash": "core-issued-plan-hash",
  "input": {},
  "preview_token": "required-for-apply-when-risk-is-write-or-destructive"
}
```

Core는 action별 input schema와 capability를 소유한다. `action_type`은 동작 종류이고 `action_id`는 한 plan/run을
끝까지 연결하는 stable identity다. `preview` 결과는 canonical target, source/destination context,
requested/effective permission, side effects, risk(`read|write|destructive`), plan hash, backup/checkpoint,
expiry와 승인 문구를 포함한다. apply는 preview와 같은 action ID, plan hash, target revision/policy일 때만
허용하며 달라지면 `STALE_PREVIEW`로 거부한다.

### 최소 action family

| Area | typed action | 안전 경계 |
|---|---|---|
| Today/Projects | `resume_project`, `open_work_location` | canonical repo/worktree/provider identity fresh-read; 한 target만 launch |
| Inbox | `classify_inbox_item`, `link_inbox_project`, `archive_inbox_item` | source/destination context, revision, duplicate set 확인 |
| Projects | `update_task`, `update_decision` | canonical Markdown revision 대상, atomic file write + projection refresh |
| Runs & Agents | `jump_agent`, `start_agent`(E2 이후), `review_run` | Orca capability/effective permission; result pointer만 Core에 기록 |
| Integrations | `sync_adapter`, `disconnect_adapter`, `clear_adapter_cache` | account/scope/cursor 구분; remote delete와 분리 |
| System & Recovery | `rebuild_projection`, `create_backup`, `restore_backup` | canonical store 불변, backup/schema 검증, destination preview; safe completion 또는 same-action CLI handoff |

현재 executable v1 baseline은 public table의 14개가 아니라, 코드/test에 있는 `update_secret`을 포함한 **15개
action**이다. 이 action들(`open_project`, `attach/adopt/stop_session`, environment/profile/Secret mutation,
Agent/task jump/stop, history clear, workflow run)은 즉시 제거하지 않는다. target action으로 mapping될 때까지 현재 owner revalidation,
token/origin/body limit, backup, allowlisted argv와 error contract를 유지한다. 특히 현재 제공되는 destructive
action을 새 화면에 자동 노출하지 않으며 각 action의 제품 phase와 ownership gate를 다시 통과시킨다.

`update_secret`은 S1의 `/settings` compatibility surface에서만 현재 typed set/remove, write-only value와
metadata-only response를 유지한다. target owner는 Integrations의 account/credential connection이고 System &
Recovery는 store availability/recovery를 read-only로 참조한다. S2 zero-leak와 S3 plan/revision gate 전에는 새
Integrations screen에 복제하거나 재노출하지 않는다.

### outcome과 retry

- 공통 결과: `succeeded`, `blocked`, `retryable`, `partial`, `unknown`; 단일 `failed`만 반환하지 않는다.
- partial은 surviving resource/artifact, completed step, failed step와 recovery instruction을 필수로 가진다.
- read/idempotent action만 bounded auto-retry한다. write timeout은 provider/canonical state를 재조회한다.
- journal은 action ID, target, policy/revision, 승인, 시각, outcome, artifact/recovery pointer를 저장하며 Secret,
  prompt와 command output 전문은 저장하지 않는다.
- HTTP는 loopback, same-origin per-process token, restrictive CSP/no-CORS/no-store와 bounded request를 유지한다.
- v1 action JSON의 normative maximum은 **16 KiB(16,384 bytes)**다. 16,385 bytes 이상은 HTTP 413으로
  service/action 실행 전에 거부하고 body나 decoder diagnostic을 echo하지 않는다. 구현의 약 16 MiB+64 KiB constant는 S1에서 줄이며,
  threshold test가 통과하기 전에는 문서만 큰 값으로 바꾸지 않는다.
- browser는 backend error code와 allowlisted user message/recovery만 렌더한다. raw `message/details`, command
  diagnostics, cwd/home/registry path, provider payload와 Secret metadata를 generic notice에 넣지 않는다.

## 10. S0–S9 stage별 Dashboard deliverable과 acceptance

구현 dependency와 stage close/stop은 [staged roadmap](IMPLEMENTATION-ROADMAP.md)이 소유한다. 이 절은 그
stage마다 Dashboard가 전달하고 측정할 UX를 정하며, Dashboard를 CLI 뒤의 별도 polish phase로 미루지 않는다.
roadmap의 `Runs`와 `Recovery`는 각각 user-facing **Runs & Agents**와 **System & Recovery**의 축약어다.

기존 UX workstream 이름은 탐색용 alias로 유지한다: Phase 0=S0, Phase 1=S1 System & Recovery slice+S3 parity
foundation, Phase 2=S2→S3·S4A→S4B·S7A/B→S7C, Phase 3=S5→S6, Phase 4=S8과 별도 S9다. alias는
underlying dependency를 압축하지 않으며 각 card/action은 acceptance를 통과한 capability만 enable한다.

### S0 — Phase 0 contract와 gap report

Deliverable:

- 현재 Overview/Projects/Activity/Settings/System route/action을 목표 여섯 영역에 mapping하고 current/planned,
  owner, capability와 migration gap을 기록한다. 구현 변경은 하지 않는다.
- target IA, Orca/native-terminal/tmux/cmux ownership, C1–C3/O1–O3/Secret과 compatibility policy를 잠근다.

Acceptance:

1. 현재 v1 action이 모두 owner와 target area에 mapping되고 누락·중복 owner가 0개다.
2. Orca default, native recovery, worktree별 human tmux, tmux 밖 Orca Agent와 optional cmux가 한 matrix에 있다.
3. planner/backend/frontend가 동시에 수정할 file owner가 0개인 S1–S3 change map을 만들 수 있다.

### S1 — trust foundation와 System & Recovery shell

Deliverable:

- profile, capability/support tier, manifest freshness, last verified checkpoint와 exact recovery command를 표시한다.
- Windows Terminal/iTerm2 bootstrap·doctor·restore와 Markdown/Git/tmux direct fallback을 안내한다.
- install/repair는 자동 실행하지 않고 CLI의 backup/verify/restore dry-run receipt로 handoff한다.

Acceptance:

1. WSL fresh setup+doctor 2회, update 2회와 synthetic restore 1회의 evidence가 같은 manifest/checkpoint로 표시된다.
2. macOS 미통과 fixture는 experimental이며 지원 완료로 보이지 않는다.
3. Workbench/Orca unavailable 상태에서 native recovery command까지 keyboard로 도달하고 canonical state를 바꾸지 않는다.

### S2 — canonical core read surface

Deliverable:

- read-only Inbox/Today/Project skeleton, projection revision/freshness/rebuild status와 canonical file link를 제공한다.
- C1–C3/O1–O3 class와 receipt provenance를 detail에서 보여주고 parse/corrupt error에 file/field/recovery를 붙인다.

Acceptance:

1. SQLite/sidecar 삭제 후 clean rebuild에서 canonical object·important receipt 유실이 0이고 stable relation이 100%다.
2. export→clean import→rebuild에서 stable relation과 query equivalence가 100%다.
3. Secret fixture가 Markdown, SQLite, search, log와 Dashboard snapshot/DOM에 0건 나타난다.
4. empty, stale, partial, parse error와 unavailable fixture가 서로 다른 accessible status/name을 가진다.

### S3 — CLI/Dashboard parity closed loop

Deliverable:

- Today, Inbox triage, Project resume와 Runs & Agents/recovery panel에서 같은 `ActionPlan/ActionRun`을 사용한다.
- 같은 action ID/plan hash 승인, stale-plan rejection과 terminal-required action의 exact `wb` handoff를 제공한다.
- 기존 `/activity` deep link와 v1 security/action contract를 compatibility 기간 동안 유지한다.

Acceptance:

1. 실제 Inbox 20개/closed loop 3개에서 provenance가 100%이고 capture median이 10초 이하다.
2. resume median이 60초 이하 또는 baseline 대비 30% 개선된다.
3. parity fixture에서 plan hash, state transition, outcome/error code와 receipt schema mismatch가 0이다.
4. partial failure의 surviving asset와 next action 표시율이 100%다.
5. 360px/768px/1280px, 200% zoom과 keyboard-only에서 content/focus loss와 body horizontal overflow가 0이다.

### S4A/S4B — Orca evidence와 E1 workspace projection

S4A deliverable은 Integrations/Workspace card의 E0 sample size, current default, fallback과 promotion readiness다.
S4B는 capability/version/health, read-only worktree/Agent summary, `observed_at`, confidence, open/jump와 result
pointer를 Projects 및 Runs & Agents에 추가한다. stop/remove는 없다.

Acceptance:

1. S4A는 2주 또는 20 session 표본을 prompt/path/output 없이 표시하고, Orca 사용 30% 이상 또는 search need
   3회 이상일 때만 E1 ready가 된다.
2. S4B의 20회 resume에서 wrong-worktree jump가 0, stale handle 재탐색이 95% 이상, Orca 부재 fallback이
   100%다.
3. CLI/Dashboard가 같은 canonical target/capability error를 표시하고 tmux observation을 Orca Agent로 승격한
   record가 0개다.

### S5/S6 — GitHub 다음 Slack read

S5는 GitHub account/context/scope/health/staleness, Inbox provenance, sync/reconcile, disconnect preview와 cache
keep/delete/export를 제공한다. S6는 S5 acceptance 뒤 같은 surface와 event contract로 Slack을 추가하며
provider-specific detail만 disclosure한다.

Acceptance:

1. duplicate/out-of-order/missed event, cursor reset, 429/5xx, revoke와 wrong-context fixture에서 원문 유실,
   자동 덮어쓰기, plaintext credential과 external write가 각각 0건이다.
2. stale/auth/rate-limit은 해당 integration만 degrade하고 local Today/Inbox/Projects는 계속 동작한다.
3. GitHub는 30일 실제 read-use 표본에서 manual navigation 또는 triage time 변화가 측정된다.
4. Slack은 GitHub core contract/fixture를 재사용하고 명시된 최소 범위 밖 message body 보존이 0건이며,
   generic SDK나 broad message archive가 필요하면 시작하지 않는다.

### S7A/S7B/S7C — history, encrypted snapshot와 clean restore

Deliverable:

- System & Recovery에 GitHub history와 OneDrive snapshot의 include/exclude, physical path, last verification,
  expiry, restore drill과 recovery location을 분리해 표시한다.
- Dashboard는 plaintext key를 받지 않는다. 같은 Core restore plan을 preview하고 안전한 completion을 보장할 수
  있으면 foreground approval 뒤 실행하며, 보장할 수 없으면 같은 `action_id`의 exact CLI handoff를 제공한다.

Acceptance:

1. clean environment에서 Git history restore + snapshot decrypt/checksum + projection rebuild + doctor가 성공한다.
2. 같은 path 이중 sync, plaintext Secret/age key와 반복 conflict가 각각 0건이다.

### S8/S9 — controlled launch와 limited write gate

S8은 E1과 clean restore acceptance 뒤 Agent/worktree/setup policy/effective permission을 보이는 Orca-owned
launch plan을 추가한다. S9는 실제 반복 사례 3개 이상과 stable revision, preview diff, idempotency/CAS,
reconcile 및 undo/recovery를 모두 가진 R2 write 한 개만 foreground approval로 검토한다.

Acceptance:

1. S8의 비파괴 task 10개에서 policy 표시가 100%, result pointer가 90% 이상, duplicate launch와 credential
   leak가 각각 0건이다.
2. preview 뒤 target revision/policy 변경은 `STALE_PREVIEW`로 거부하고 write timeout 뒤 reconcile 전 retry는 0건이다.
3. arbitrary target, rollback 부재, cross-context risk 또는 orphan worker가 1건이라도 있으면 E1/최근 accepted
   checkpoint로 rollback한다.

## 11. S0 product/UX gate resolution

### 결정 요약

| Gate | 제품 결정 | defer/owner 경계 |
|---|---|---|
| 15번째 `update_secret` | executable baseline은 15개다. `/settings` compatibility에서만 보존하고 target ownership은 Integrations, store recovery read는 System & Recovery다. | public v1 action table 정정은 Workbench docs owner; 새 area mutation은 S2/S3 gate |
| action request size | 16 KiB를 normative v1 maximum으로 선택한다. 초과는 HTTP 413, fixed safe copy, service call 0이다. | error envelope field/code 이름을 새로 만들지 않으며 backend가 S1 handler/test를 소유 |
| route/deep link | S1은 현재 route를 render하고 redirect/new alias를 만들지 않는다. target alias와 ID grammar는 capability acceptance 뒤다. | backend가 route handler, frontend가 route matrix/history/focus를 소유; S2/S3 전 URL parameter 금지 |
| full refresh focus | 15초/manual/post-action refresh가 focus를 버리는 현재 동작은 S1 visible slice의 accessibility blocker다. | accepted S1 slice에서 stable existing DOM key만 사용; Core identity/deep-link는 만들지 않음 |
| sensitive paths/errors | raw error detail은 절대 generic DOM에 render하지 않는다. project canonical path는 existing Project detail에서만 유지하고 새 shell/Today에는 복제하지 않는다. | path allowlist와 server redaction은 S2/S3 threat/contract owner; compatibility path 제거는 별도 migration |
| six-area rollout | IA label은 한 번에 보이되 capability는 stage별 enable한다. unavailable Inbox와 compatibility-mapped areas를 정직하게 표시한다. | S1 shell은 새 domain data/action 0; S2/S3/S5 이후 각 capability 독립 promotion |

### 선택한 smallest user-visible slice

S1의 첫 frontend slice는 **focus-safe six-area compatibility shell** 하나다.

- global nav에 Today, Inbox, Projects, Runs & Agents, Integrations, System & Recovery를 이 순서로 보인다.
- Today=`/`, Projects=`/projects`, Runs & Agents=`/activity`, Integrations=`/settings`, System & Recovery=`/system`의
  현재 view를 사용한다. Inbox는 `준비 중 · S2 필요`와 `aria-disabled=true`를 가진 focusable control이며
  activation은 route/data/action을 만들지 않는다.
- 모든 current route에 정확히 하나의 visible `h1`, active `aria-current=page`, generated/refresh state와
  persistent failure summary를 제공한다. Guide는 primary six-area nav와 구분해 유지한다.
- manual refresh는 Refresh button, background refresh는 현재 focused control, action refresh는 invoking control로
  돌아간다. 같은 stable `id`/기존 `data-*` key의 enabled control이 사라졌으면 route `h1`에 focus하고
  `이전 항목을 더 이상 사용할 수 없음`을 polite announce한다. DOM 위치나 label text만으로 대상을 추측하지 않는다.
- compatibility Settings의 `update_secret` form과 나머지 v1 control은 현 위치·payload·confirmation을 유지한다.
  새 nav에 destructive action을 추가하거나 control을 다른 owner area로 복제하지 않는다.
- new shell과 notices는 stable ID/display name, capability와 safe fixed copy만 render한다. canonical project path는
  기존 Project detail, exact recovery path/command는 명시적 System & Recovery disclosure에서만 허용한다.
  worktree path, task CWD, Agent registry path, tmux current path/command와 raw diagnostics를 새 shell에 복제하지 않는다.

이 slice는 새로운 Inbox/Today model이나 v2 API보다 먼저 구현할 수 있지만, 아래 backend evidence가 같은
integration checkpoint에 없으면 release하지 않는다.

### exact acceptance fixtures

#### Backend/security evidence paired with the slice

1. **15-action inventory:** fixture가 `open_project`, `attach_session`, `adopt_session`, `stop_session`,
   `update_environment`, `update_profile`, `update_secret`, `start_agent`, `jump_agent`, `stop_agent`, `jump_task`,
   `stop_task`, `clear_agent_history`, `jump_pane`, `run_workflow`를 정확히 한 번씩 인식하고, 16번째 unknown action과
   unknown nested Secret field를 실행 전 거부한다. `update_secret` response/snapshot/notice에 submitted value,
   raw `sec://` reference와 vault/identity path 출현은 0건이다.
2. **body boundary:** allowlisted minimal action JSON 뒤에 JSON whitespace를 채운 exact 16,384-byte body는 typed
   decode/service call 1회, 같은 body 16,385 bytes는 HTTP 413/service call 0회다. 초과 response body와 log에
   request bytes, decoder string, Secret sentinel과 filesystem sentinel 출현은 0건이다.
3. **redacted failure:** fake action error의 raw details에 `/home/alice/private`, `C:\\Users\\Alice\\private`,
   `sec://github/token`, `TOKEN_SENTINEL`, command/stdout/stderr를 넣는다. Dashboard response의 user-facing
   message/DOM/accessibility tree/title attribute에는 sentinel 0건이고 stable existing code와 fixed recovery copy만
   나타난다.
4. **v1 regression:** loopback, token, Origin, content type, strict unknown/trailing JSON, CSP/no-CORS/no-store,
   argument arrays, current ownership revalidation, backup/partial-survivor와 all current GET/HEAD/method behavior가
   계속 통과한다.

#### Route, refresh and accessibility fixture

1. S1에서 `/`, `/projects`, `/activity`, `/settings`, `/system`, `/guide`, `/guide/`, `/docs`, `/docs/`의 current
   GET/HEAD가 유지되고
   `/today`, `/inbox`, `/runs`, `/integrations`는 404다. navigation의 six labels와 current/planned copy가 이 사실과
   모순되지 않는다.
2. browser fixture는 `/activity?source=bookmark#task-detail`과 `/settings?source=bookmark#secrets`를 load/refresh한
   뒤 `location.pathname/search/hash`가 byte-for-byte 같음을 확인한다. S3 `/runs`가 accepted된 fixture에서는
   `/activity` rendered alias가 query/hash를 유지하고 같은 capability state를 보인다.
3. focus matrix는 project button, task button, Refresh, Secret submit과 unavailable Inbox control 각각에서
   manual, timer, success, failure refresh를 실행한다. target이 남으면 `document.activeElement` stable key가 같고,
   target이 사라지면 route `h1`과 polite removal notice가 확인되며 focus가 `body`로 빠지는 경우는 0건이다.
4. 각 route는 one visible `h1`, named landmarks/nav, active `aria-current`, unavailable reason, keyboard-only order,
   visible focus와 no hover-only information을 가진다. failure summary는 persistent하고 focusable하며 field error와
   programmatically 연결된다. current native constraint가 field를 특정할 수 없는 server error는 form-level
   `aria-describedby`만 사용하고 field name을 추측하지 않는다.
5. 360/768/1280 CSS px와 200% zoom, light/dark/system, reduced motion에서 body
   `scrollWidth <= clientWidth`, content/focus loss 0, 44×44 px interactive target, body/form text 16 px 이상을
   검증한다. 360px DOM order는 page title/status → primary action → filters/navigation → content → detail이다.

### non-goals for this slice

- `/today`, `/inbox`, `/runs`, `/integrations` handler, redirect, query parameter 또는 selected-object deep-link grammar.
- Inbox/Today/Run object, Markdown/frontmatter, SQLite, `ActionPlan/ActionRun`, v2 envelope/field 또는 browser state store.
- `update_secret` 이동/복제, provider account model, Secret recovery mutation 또는 raw credential/error/path 표시.
- current destructive action의 새 navigation 노출, Orca/iTerm2/connector 구현, install/repair, automatic retry/fallback.
- framework/build-system migration, remote asset, analytics, service worker, arbitrary command/path/prompt/argv/env input.

### deferred questions and owner feedback

- **PM:** S1 checkpoint는 이 slice와 backend evidence를 한 묶음으로 accept/stopped 처리하고 여섯 label의 존재를
  여섯 capability 완료로 보고하지 않는다. `/activity` removal observation이 없으면 compatibility를 유지한다.
- **Backend:** public v1 table을 15 actions로 정정하고 16 KiB/413/redaction tests를 소유한다. generic error
  response에 raw `err.Error()`/details를 전달하지 않으며 route alias와 S1 recovery capability source를 결정한다.
- **Frontend:** existing v1 payload를 바꾸지 않는 adapter 뒤에 navigation/focus/safe-notice seam을 둔다. label,
  DOM order나 text로 focus identity를 만들지 않고 disabled Inbox activation과 raw error rendering을 막는다.
- **Validation:** real browser harness에서 route/search/hash, timer/action focus matrix, accessibility tree sentinel,
  360/768/1280+200% zoom과 44×44/16px를 실행한다. Node/Go-only 결과는 browser acceptance를 대체하지 않는다.
- **Deferred to S2/S3:** stable object URL grammar, canonical path allowlist, structured error/recovery fields,
  Settings split의 final route, profile/credential target view model과 alias retirement mechanism이다.

### S1 committed compatibility-lock UX acceptance review — 2026-08-10

검토 대상은 Workbench `e80187e`(action request limit)와 `6d7750c`(focus-safe compatibility shell), 두 role log,
embedded HTML/JS/CSS, Go handler fixtures와 Node fixtures다. 이 gate는 두 commit을 **bounded implementation
checkpoint로 accept**하지만 real-browser product acceptance나 S1 capability completion으로 promote하지 않는다.

| 판정 | 항목 | commit/fixture evidence | 남은 조건 또는 dissent |
|---|---|---|---|
| **Accepted** | six labels/order와 current destination | `navigation_test.mjs`가 Today, Inbox, Projects, Runs & Agents, Integrations, System & Recovery 순서와 `/`, non-link Inbox, `/projects`, `/activity`, `/settings`, `/system`을 고정한다. `/today`, `/inbox`, `/runs`, `/integrations` link가 없고 Go fixture는 target route 404를 확인한다. | label은 capability 완료가 아니며 Guide는 별도 Help nav다. |
| **Accepted** | focusable non-link Inbox semantics | HTML은 native `button`에 `aria-disabled=true`, reason association과 S2 copy를 사용하고 `disabled`/`href`/route/action을 만들지 않는다. activation은 local polite notice만 낸다. | 아래 timer-focus dissent는 별도다. |
| **Accepted** | v1 compatibility/backend pair | `e80187e`는 15 action transport fixtures, exact 16,384-byte execute 1회와 16,385-byte HTTP 413/execute 0, current GET/HEAD와 target 404를 고정한다. | 이는 새 domain/API acceptance가 아니다. |
| **Accepted** | no second state owner | frontend diff는 기존 in-memory `state.projectId`/`state.taskId`를 유지하고 URL/storage/history/Core replica를 추가하지 않는다. focus identity는 한 refresh를 위한 ephemeral descriptor이며 domain state가 아니다. | S2/S3 전 selected-object persistence/deep link를 추가하지 않는다. |
| **Partial** | current route preservation | app은 `location`/History API를 쓰지 않고 current document에서 snapshot/action fetch만 하며 server fixture는 current route를 그대로 render한다. | `/activity?source=bookmark#task-detail`와 `/settings?source=bookmark#secrets`의 path/search/hash byte equality는 Node/Go fixture가 없고 real browser에서 아직 미실행이다. |
| **Partial** | deterministic focus/fallback | Node helper fixture는 stable id/data/form identity, removed/disabled/hidden fallback, route-heading focus와 fixed polite notice를 검증하고 manual/timer/action wiring을 정적으로 확인한다. | 실제 fetch/render와 keyboard focus를 함께 실행하지 않는다. 또한 focusable Inbox가 DOM에 남아도 `aria-disabled`라 timer refresh 때 heading으로 이동한다. 이는 “background refresh는 current focus로 복귀”와 충돌하므로 그대로 accept하지 않는다. |
| **Partial** | safe failure copy와 sensitive detail | frontend는 backend `message/details`를 읽지 않고 allowlisted code와 fixed snapshot/action copy만 persistent alert/notice에 넣으며 raw Doctor reason notice도 제거했다. oversized-request response도 fixed copy/empty details다. | generic handler는 여전히 일부 `err.Error()`와 typed action details를 API response에 전달한다. hostile message/details가 DOM/accessibility tree/title에 0건임을 증명하는 executable end-to-end fixture도 없으므로 redacted-failure acceptance 전체는 미충족이다. |
| **Partial** | responsive/accessibility | semantic nav/Help separation, active `aria-current`, focusable headings/alert, narrow reflow rules, 44px controls와 16px narrow text는 static HTML/CSS/Node assertions로 확인된다. | 360/768/1280, 200% zoom, keyboard order, focus ring, overflow, screen-reader tree, themes/reduced-motion은 real browser evidence가 없다. |
| **Rejected** | “S1 UX acceptance complete” 또는 “responsive/accessibility passed” 주장 | frontend log도 browser harness 부재를 명시한다. source-regex/VM helper와 Go route tests는 rendering engine, actual focus lifecycle 또는 accessibility tree를 실행하지 않는다. | 아래 evidence가 생길 때까지 release report는 `implementation accepted; product validation pending`이라고 써야 한다. |

#### remaining validation과 exact acceptance fixtures

1. real browser에서 `/activity?source=bookmark#task-detail`와 `/settings?source=bookmark#secrets`를 initial load,
   manual refresh, timer refresh, successful action refresh와 failed action 뒤 각각 검사해
   `pathname+search+hash` byte equality를 100% 확인한다.
2. project/task/Refresh/Secret submit/Inbox 각각을 keyboard로 focus하고 same five lifecycle을 실행한다. 남아 있는
   focusable control은 same stable identity, 제거·disabled·hidden control은 visible route `h1`+polite notice,
   `document.body`/destructive neighbor focus는 0건이어야 한다. Inbox가 남아 있는 timer case는 현재 예상 실패다.
3. 360/768/1280 CSS px와 200% zoom에서 light/dark/system, reduced motion, keyboard-only로 one visible `h1`, named
   nav/landmarks, active/unavailable announcement, visible focus, 44×44 target, 16px form text,
   `scrollWidth <= clientWidth`, content/focus loss 0을 viewport별 evidence로 남긴다.
4. snapshot/action fake response의 message/details에 Unix/Windows path, `sec://`, token, command/stdout/stderr와
   markup sentinel을 넣고 user-visible DOM, accessibility tree, title/attribute의 sentinel 0건을 확인한다. 별도로
   API response redaction은 backend contract owner가 유지할 raw v1 compatibility와 S1 security fix 범위를 결정한다.

#### product decision, non-goals와 role feedback

- **Decision:** 두 commit은 rollback 없이 유지할 수 있는 S1 v1 compatibility implementation checkpoint다. 다음
  product decision은 frontend가 **DOM에 남아 있는 focusable Inbox에는 timer refresh 후 focus를 유지**하도록
  unavailable-for-activation과 unavailable-for-focus-restore를 분리한 evidence를 제시하거나, PM이 background-focus
  contract 예외를 명시적으로 승인하는 것이다. 그 결정과 real-browser fixtures 전에는 UX gate를 close하지 않는다.
- **PM feedback:** six labels, backend lock과 static focus seam은 accept하되 S1 완료로 보고하지 않는다. browser gap,
  Inbox timer 예상 실패와 generic API redaction boundary를 validation/owner decision으로 추적한다.
- **Backend feedback:** exact body/action/route fixtures는 accepted다. fixed 413 이외 generic `err.Error()`/details가
  response에 남는 current v1 behavior를 “safe end-to-end failure”로 표현하지 말고 redaction scope를 별도 gate한다.
- **Frontend feedback:** nav/Inbox/no-new-owner와 fixed DOM copy는 accepted다. route byte-preservation, actual
  fetch/render focus matrix와 responsive/a11y는 browser fixture로 증명하고 Inbox restore predicate를 해소한다.
- **Non-goals:** 이 review에서 새 target route, URL identity grammar, Inbox/Today/Run schema, Markdown/SQLite projection,
  v2 error envelope, application-service 또는 browser store를 설계하지 않는다. current v1 control/payload/ownership,
  compatibility routes와 existing selected Project/Task state도 이동하지 않는다.

## 12. 출시 전 공통 검증

- unit/contract: Core owner, schema/version, unknown field, revision/idempotency, redaction, error/outcome fixture.
- browser: keyboard, screen reader landmark/name, theme/contrast, reduced motion, zoom 200%, responsive screenshots.
- security: loopback/origin/token/CSP/body limit, argument array, canonical target revalidation, Secret/prompt/path redaction.
- recovery: corrupt projection, provider outage, expired auth, partial launch, interrupted restore와 last-known-good rollback.
- parity: 대표 capture, triage, resume, review, rebuild를 CLI와 Dashboard에서 교차 실행해 같은 canonical 결과 확인.

Dashboard의 성공은 화면 수가 아니라 4주 자발적 Today/review 사용, capture/복귀 시간, provenance 보존,
잘못된 context write와 복구 불가능한 partial run이 줄어드는지로 판단한다. 자발적 사용률이 50% 미만이거나
fallback이 20%를 넘으면 Dashboard를 operations 보조 UI로 유지하되 CLI/Core 계약과 복구 경로는 그대로 둔다.
