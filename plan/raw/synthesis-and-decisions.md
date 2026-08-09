# 멀티 에이전트 조사 통합 판단

> 기준일: 2026-08-10
> Orca run: `run_effd9e1cba83`
> 범위: A 제품 전략, B 사용자 시나리오, C 기술·보안, D 우선순위, E Agent orchestration

이 문서는 워커 보고서를 단순 합치지 않고, 서로 다른 전제와 충돌을 비교해
[통합 제품 기획서](../PRODUCT-PLAN.md)에 반영한 결정을 기록한다. 각 보고서의 외부 사실과 출처는 원문을
따르며, 아래의 선택은 제품 판단이다.

## 1. 워커별 핵심 주장

| 영역 | 강한 결론 | 반론·불확실성 |
|---|---|---|
| A 전략 | 문제는 앱 부족이 아니라 작업 맥락·통제·복구의 단절이며 `Prepare–Resume–Recover`가 첫 쐐기다 | 기존 도구 조합보다 통합 UX가 실제로 나은지는 사용 관찰 전에는 모름 |
| B 시나리오 | local Inbox에서 review·실행·복구까지 닫힌 루프가 필요하고 Today는 원본이 아닌 projection이어야 한다 | calendar/mail/Slack 등 하루 시나리오가 넓어 MVP로 그대로 가져가면 과대 범위가 됨 |
| C 기술·보안 | local state와 adapter 경계를 분리하고 최소 권한, journal, backup/restore, graceful degradation을 계약으로 둬야 한다 | OS·provider별 원자성, auth, webhook 동작은 실제 장비·계정 smoke가 필요 |
| D 우선순위 | 첫 30일은 profile, Tier-1, 검증 lock, fresh/restore를 닫고 새 통합을 강하게 제한해야 한다 | 신뢰성만 만들면 넓어진 제품 가치를 검증하지 못하고 설치 도구로 회귀할 위험이 있음 |
| E Agent | Orca를 optional backend로 통합하되 Orca runtime lifecycle을 복제하지 말고 read-only부터 시작한다 | Orca 사용 빈도와 CLI 장기 안정성, metadata-only audit의 충분성이 아직 미확인 |

## 2. 전 영역의 합의

1. 제품의 최종 목표는 개발환경 설치가 아니라 local-first 개인 운영 환경이다.
2. 외부 원문을 중앙화하지 않고 reference, projection, provenance와 다음 행동을 연결한다.
3. 개인/업무 통합은 저장소 통합이 아니라 탐색·계획의 통합이며 자격 증명과 write 권한은 분리한다.
4. 자동화는 preview, explicit approval, journal, partial failure, disable과 recovery를 함께 가져야 한다.
5. MCP는 여러 adapter 중 하나이고 범용 proxy나 핵심 data model이 아니다.
6. terminal, Git, local file의 독립 경로는 UI와 외부 서비스 장애 때도 남아야 한다.
7. 새 추상화와 integration은 실제 반복 사용과 승격 gate 뒤에 추가한다.

## 3. 주요 충돌과 선택

### 충돌 A — 30일 신뢰성 동결 대 개인 운영 루프 구현

- D는 현 상태의 platform 주장, profile, lock과 restore가 엇갈리므로 새 Dashboard/backend 기능을 30일
  동결하자고 제안했다.
- A와 B는 실제 capture→resume→review 루프를 만들지 않으면 제품 차별화와 사용자 가치 가설을 검증할 수
  없다고 본다.

**선택:** 둘을 병렬 기능군으로 확장하지 않고 **하나의 세로 절단면**으로 결합한다. MVP gate에 Tier-1,
profile, fresh/restore를 포함하면서, 외부 서비스 없이 file/stdin capture 하나가 project/task, resume,
review journal까지 이어지는 단 한 개의 닫힌 루프를 만든다. 두 번째 integration과 새 native UI는 동결한다.

### 충돌 B — Workbench가 제품인가 optional component인가

- 현재 구현은 Workbench가 구조화 state와 Dashboard를 제공하지만, 문서의 독립 terminal 원칙과 setup의
required 정책이 충돌한다.
- Workbench를 필수 IDE로 만들면 제품 메시지는 간단해지지만 Go/server 문제 하나가 환경 복구 전체를
막는다.

**선택:** 제품은 Setup 전체이고 Workbench는 local structured core다. 일반 설치는 `workbench` profile을
기본으로 하며 Workbench를 필수 검증한다. `terminal` profile은 Workbench 없이 tmux·LazyVim·binbox를
복구하거나 최소 설치할 때 명시적으로 선택한다.

### 충돌 C — 넓은 정보 구조 대 작은 MVP schema

- B의 Today/Inbox/Projects/Areas/Library/Runs/Integrations/System 구조는 장기 경험을 잘 설명한다.
- 이를 모두 독립 모듈로 구현하면 notes·task manager·automation suite를 동시에 만드는 셈이다.

**선택:** 사용자 정보 구조는 장기 navigation map으로 채택하지만 MVP 객체는 `Context`, `InboxItem`,
`Project`, `Task`, `ExternalRef`, `WorkLocation`, `Run`으로 제한한다. Area, Library, recurring Automation은
schema 확장 전에 실제 query와 review 사용을 관찰한다.

### 충돌 D — 자체 Agent control plane 대 Orca 통합

- 자체 구현은 vendor 독립성과 개인 workflow 최적화를 줄 수 있다.
- Orca는 이미 worktree, terminal, agent, Run/Task/Dispatch와 lifecycle을 소유한다. Workbench가 이를
복제하면 stale state와 dual ownership을 해결하는 별도 제품이 된다.

**선택:** Orca를 cmux와 같은 optional backend/client로 채택하되 더 엄격한 ownership 경계를 둔다.
Workbench는 장기 Task와 policy, opaque provider reference, 관찰 시각과 결과 pointer만 소유한다. E0 사용
관찰 뒤 E1 read-only health/summary/open/jump, E2 controlled launch, E3 pass-through 순으로 승격한다.
자체 scheduler/message bus/DAG는 cross-backend 수요 gate 전까지 비목표다.

### 충돌 E — local file 대 SQLite 중심 저장

- 열린 Markdown과 Git은 탈출구, diff, 수동 복구가 강하다.
- query, dedupe, run journal과 cursor는 transaction이 있는 local store가 유리하다.

**선택:** LLM wiki 방식처럼 Markdown을 task·note·decision의 canonical authoring format으로 삼고 stable
ID와 최소 frontmatter를 둔다. 중요한 receipt와 authoritative local operation은 portable journal에 먼저
확정하고, SQLite는 검색, dedupe, cursor와 journal query를 위한 재구축 가능한 projection이며 Markdown이나
portable journal을 대체하지 않는다. 상세 frontmatter와 rename 규칙만 MVP prototype에서 확정한다.

### 충돌 F — 첫 외부 연동

- GitHub/Slack은 개발 요청의 빈도가 높을 수 있고, calendar busy는 개인/업무 전체 Today 가치가 크다.
- 실제 주간 사용량과 계정 권한, provider 선택이 기록되지 않았다.

**선택:** MVP는 file/Git만 사용한다. 90일 connector는 GitHub read-only metadata를 먼저 만들고, 같은
provenance·cursor·health 계약을 재사용할 수 있을 때 Slack read-only를 잇는다. calendar는 이후 실제
사용 빈도로 재평가하며 MCP 사용 여부로 선택하지 않는다.

## 4. 최종 제품 방향

제품의 쐐기는 **Prepare–Resume–Recover를 관통하는 개인 운영 loop**다.

- Prepare: 한 Tier-1 장비와 profile에서 setup, policy, data와 실행 도구를 준비한다.
- Resume: Inbox/Today/Project에서 원문, 다음 행동과 안정된 실행 위치로 돌아간다.
- Recover: 실패를 partial/retryable/blocked로 이해하고 journal, backup, direct path로 복구한다.

통합은 데이터 수집량이나 지원 서비스 수로 평가하지 않는다. `미분류 항목`, `복귀 시간`, `원문이 끊긴
task`, `복구 불가능한 run`, `잘못된 context write`가 줄어드는지로 평가한다.

## 5. 채택한 30일 MVP

### 포함

- profile prerequisite와 실제 Tier-1 한 개
- 검증 날짜·run·rollback이 붙은 lock manifest
- fresh setup/update/doctor와 synthetic restore
- personal/work Context, local Inbox와 provenance
- Project/Task/ExternalRef/WorkLocation과 Today/Next projection
- typed action preview/approval와 Run journal
- file/stdin capture, file/Git adapter와 local search
- 2주/20 session Orca E0, gate 충족 시 read-only E1 spike

### 포함하지 않음

- calendar/mail/Slack/Teams/Docs 양방향 sync
- MCP config mutation과 lifecycle manager
- Orca stop/remove, 자동 task dispatch와 자체 DAG
- cloud sync, remote runner, desktop/mobile native shell
- 자연어 arbitrary automation과 generic plugin/proxy

## 6. Agent 관리에 대한 구체 결정

첫 Orca adapter는 아래만 허용한다.

1. `status --json`과 capability/version 확인
2. worktree·agent terminal의 읽기 전용 summary와 `observed_at`
3. canonical repo/path/branch를 재검증한 open/jump
4. E2에서만 agent, worktree, effective permission을 미리 보이는 launch
5. outcome, 변경 파일, test, commit/PR 같은 result pointer를 Task에 연결

prompt와 terminal 전문은 기본 저장하지 않고 runtime handle을 영구 ID로 사용하지 않는다. stop/remove는
초기 범위가 아니다. Orca 부재, version 불일치, 상태 미확인 시 tmux/Git/direct agent 경로로 degrade한다.

## 7. 남은 결정과 증거

- WSL primary Tier-1과 macOS 병행 track의 실제 smoke 결과
- 첫 20개 Inbox 항목과 매일 쓰는 대표 세 흐름
- portable authoring format과 projection DB 경계
- GitHub·Slack의 account/context scope와 retention
- private GitHub history와 암호화된 OneDrive snapshot의 실제 restore·충돌 결과
- Orca E0 사용률, metadata-only result/audit의 충분성
- 실제 Linux/WSL/macOS 장비와 provider 계정에서의 security/recovery smoke

## 8. 문서 적용 결과

- 제품 정의, MVP, roadmap과 stop criteria는 [PRODUCT-PLAN.md](../PRODUCT-PLAN.md)에 반영한다.
- 상세 사실·반론·불확실성·외부 출처는 각 worker raw 보고서에 보존한다.
- 완료된 이전 계획은 기존 archive에 그대로 두며, 활성 영역에서 추가 이동할 완료 계획은 발견되지 않았다.
- binbox 명령 문서는 독립 운영·복구 경로이므로 정리·삭제 대상으로 취급하지 않는다.

## 9. 2026-08-10 Phase 0 Dashboard·workspace 결정 addendum

현재 Dashboard의 loopback, same-Core client, typed action, ownership 재검증, responsive/accessibility 자산은
버릴 대상이 아니라 제품 경험의 기반으로 채택했다. operations console은 Today, Inbox, Projects,
Runs & Agents, Integrations, System & Recovery의 여섯 영역으로 발전한다. 현재 Overview/Activity/Settings의
기능은 각각 새 영역에 이행하고, `/activity` 같은 기존 deep link와 v1 action은 호환 기간 동안 보존한다.
상세 target contract와 phase별 인수 기준은 [Dashboard 제품·UX 명세](../DASHBOARD-SPEC.md)가 소유한다.

Dashboard와 `wb` CLI는 Workbench Core의 동등한 client다. Dashboard, browser localStorage 또는 SQLite가
사용자 task/decision, provider runtime이나 외부 원문의 두 번째 owner가 되어서는 안 된다. Markdown은
사용자 작성 정보의 canonical format, SQLite는 재구축 가능한 projection이며, private GitHub는 그
Markdown·설정 history를 보존하고 OneDrive는 Secret을 제외한 암호화 snapshot·attachment·runtime backup을
담당한다. 같은 working tree의 Git/OneDrive 이중 sync는 금지한다.

terminal/runtime 역할도 다음과 같이 확정했다. Orca가 기본 terminal workspace이자 Agent runtime owner이고,
Agents는 Orca 아래에서 직접 실행한다. tmux는 Orca worktree별 사람의 shell/editor 작업을 나누는 partition,
Windows Terminal과 iTerm2는 각 OS의 native fallback, cmux는 선택적 macOS client다. Workbench는 Orca의
Run/Task/Dispatch lifecycle을 복제하지 않고 opaque reference, capability, 관찰 시각과 result pointer만
투영한다. iTerm2 adapter와 새 navigation/API는 Phase 0 결정이지 현재 구현 완료 주장이 아니며, 구현 전까지
capability를 unavailable로 정직하게 표시한다.

PM architecture/roadmap cross-review에서 저장과 delivery 용어를 더 엄밀하게 맞췄다. Markdown canonical과
SQLite projection이라는 원칙은 유지하되, state를 C1–C3, O1–O3와 Secret으로 분류하고 중요한 receipt와
O1 checkpoint를 portable journal에 먼저 확정한다. 따라서 pending mutation, fencing key와 unreconciled
outcome을 SQLite에만 저장한 채 rebuildable이라고 부르는 설계는 허용하지 않는다.

제품 horizon(0~30일/31~90일/장기)은 stage 완료를 대신하지 않으며 구현 gate는
[IMPLEMENTATION-ROADMAP.md](../IMPLEMENTATION-ROADMAP.md)의 S0–S9가 소유한다. CLI/Dashboard parity는 같은
application service를 사용한다는 선언뿐 아니라 같은 fixture/action의 plan hash, state transition,
outcome/error code와 receipt schema mismatch 0으로 판정한다. roadmap의 `Runs`와 `Recovery`는 user-facing
**Runs & Agents**와 **System & Recovery**의 축약어로 해석해 navigation owner를 둘로 만들지 않는다.
