# 사용자 시나리오와 기능 후보

> 상태: 제품 경계 결정을 위한 raw 조사·제안
> 기준일: 2026-08-10
> 대상: 개인 업무와 개발 업무를 한 환경에서 운영하는 숙련 사용자 1명

이 문서는 현재 구현을 확정 요구사항으로 간주하지 않는다. 현재 기능에서 재사용할 수 있는 안전
계약을 확인하고, 실제 하루와 `수집 → 정리 → 계획 → 실행 → 검토 → 자동화` 루프를 기준으로 다음
제품 후보를 넓게 탐색한다.

표기 규칙은 다음과 같다.

- **[사실]** 저장소 구현 문서, 코드 기준선 또는 외부 1차 자료로 확인한 내용
- **[추론]** 사실에서 도출했지만 실제 사용 관찰로 검증하지 않은 판단
- **[제안]** 채택 여부와 설계가 아직 결정되지 않은 제품 후보
- 빈도는 telemetry가 아니라 시나리오 가설이다. `매일/주 여러 번/주간/월간·예외`로 표시한다.

## 1. 조사에서 확인한 출발점

### 현재 자산

- **[사실]** setup은 root provisioning, binbox, nvim/tmux, Workbench, macOS 선택 client인
  cmux-config의 다섯 저장소로 구성된다. tmux·LazyVim·`bb`는 Workbench 장애와 무관한 독립 작업
  경로로 설계됐다.
- **[사실]** Workbench에는 project/environment/local secret/session/worktree/Agent/typed workflow,
  overview/doctor, loopback Dashboard가 구현돼 있다. registry 변경은 기존 파일 backup과 검증을
  사용하고, observed process나 외부 worktree에는 변경 권한을 추측해 부여하지 않는다.
- **[사실]** Dashboard는 별도 state owner가 아니라 core의 client이며, loopback과 per-process token,
  typed action을 사용한다. arbitrary command 입력은 제공하지 않는다.
- **[사실]** 현재 제품은 문서·캘린더·메시지·메일·북마크를 일반적인 업무 객체로 수집하거나 통합
  계획으로 변환하는 기능은 구현하지 않았다. MCP 관리 역시 장기 후보이지 현재 기능이 아니다.
- **[사실]** 실제 일상 사용 빈도, 장기간 scheduler 안정성, macOS/cmux와 Windows/WSL 대표 흐름의
  물리 장비 증거는 아직 없다.

### 제품 범위에 대한 해석

- **[추론]** 현재 Workbench의 ownership, typed action, backup, doctor 계약은 통합 도구의 실행·복구
  기반으로 재사용할 가치가 크다. 반면 Workbench 객체를 모든 업무 데이터의 유일한 형식으로 즉시
  확대하면 과도한 중앙화와 schema 결합이 생길 수 있다.
- **[추론]** 사용자가 실제로 원하는 단위는 “도구”보다 “맥락과 다음 행동”이다. Git repository,
  문서, 일정, 메시지, 인프라 환경은 서로 다른 source of truth를 유지하되 로컬 index에서 한 프로젝트와
  한 작업으로 연결해야 한다.
- **[제안]** 제품의 중심을 `개인 운영 코어 + 얇은 adapter`로 둔다. 코어는 로컬 inbox, project/task,
  provenance, 실행 이력, 정책과 복구를 소유하고, 원문과 외부 객체의 최종 권위는 파일/Git/각 서비스에
  남긴다. MCP는 adapter 종류 중 하나다.

## 2. 실제 하루 시나리오

### 사용자와 경계 가정

이 시나리오의 사용자는 인프라·개발 업무를 하면서 개인 일정, 읽을거리, 생활 반복 업무도 같은 장비에서
관리한다. 개인 계정과 업무 계정은 자격 증명, 저장 위치, 외부 쓰기 권한을 분리한다. 통합 화면은 두
영역의 제목·마감·상태 같은 허용된 metadata를 함께 보여줄 수 있지만, 개인 원문을 업무 서비스로 또는
업무 원문을 개인 저장소로 자동 복제하지 않는다.

### 하루 흐름

| 시각 | 실제 상황 | 도구가 제공할 흐름 | 실패 시 계속할 경로 |
|---|---|---|---|
| 07:50 | 휴대전화에서 본 기사와 저녁에 할 일을 빠르게 남긴다 | **[제안]** `inbox add` 또는 watched Markdown 파일에 URL·한 줄을 기록하고 `personal` provenance를 붙인다 | 네트워크가 없어도 로컬 파일에 기록; 나중에 중복 제거 |
| 08:30 | 업무 시작 전 오늘 일정, 마감, 어제 중단한 Agent와 실패한 자동화를 본다 | **[제안]** Today가 캘린더 busy block, due task, resumable terminal, 실패 run을 한 화면에 표시한다 | 외부 sync 실패는 stale 시각과 원인을 표시; tmux와 로컬 task는 계속 사용 |
| 08:40 | Slack 요청, GitHub review, 개인 메모를 분류한다 | **[제안]** Inbox에서 `project`, `area`, `next action`, `defer/reference`를 지정한다. AI는 분류를 제안만 한다 | 원문 링크와 source account를 보존; 모호하면 inbox에 남김 |
| 09:00 | 업무 repository의 PR review를 시작한다 | 등록 project에서 branch/worktree를 만들고 관련 issue·문서·체크리스트를 묶어 nvim/tmux로 연다 | 외부 worktree는 read-only로 표시; 생성 후 registry 기록 실패 시 살아 있는 path를 알려 수동 복구 |
| 10:20 | Kubernetes 경보 대응 요청이 온다 | 업무 context와 cluster/namespace를 확인하고 read-only 진단부터 실행한다. 변경 명령은 별도 승인한다 | 자격 증명 만료 시 해당 adapter/run만 중단; 명령, exit code, stderr, 복구 안내 보존 |
| 11:30 | 조사 결과를 업무 문서와 작업에 반영한다 | 로컬 note에 근거 URL·발췌 대신 요약·결정을 남기고 외부 문서는 명시적 push로 갱신한다 | 충돌 시 양쪽 버전을 보존하고 자동 덮어쓰기 금지 |
| 12:30 | 점심 중 개인 예약 알림을 확인한다 | 개인 영역 task를 완료하거나 저녁으로 이동한다. 업무 화면에는 private detail 대신 busy만 보일 수 있다 | 캘린더 쓰기 실패 시 로컬 변경을 pending으로 남기고 재시도 여부를 묻는다 |
| 14:00 | 기능 구현을 Codex에 맡기고 다른 문서를 검토한다 | project/worktree/요구사항 snapshot을 붙여 managed Agent를 시작하고 안정된 terminal 위치를 기록한다 | Agent 상태를 추측하지 않고 registry와 terminal 증거를 구분; 직접 실행한 Agent는 observed로만 표시 |
| 16:00 | test 실패 후 Agent 결과를 검토한다 | diff, test 결과, 원래 요구사항, 미해결 항목을 review packet으로 모은다. merge/push는 사용자가 결정한다 | 자동화의 stdout 전체 대신 artifact 위치와 결과 metadata를 남기고 terminal 원문으로 이동 |
| 17:30 | 오늘 한 일과 내일 첫 행동을 정리한다 | 완료/대기/차단을 project별로 검토하고, 미분류 inbox와 실패 run을 비운다 | 외부 서비스가 내려가도 local review는 완료; sync debt를 별도 표시 |
| 19:00 | 반복된 수동 단계를 자동화 후보로 승격한다 | 세 번 이상 반복된 명령 묶음을 기록해 typed workflow 초안을 만들고 dry-run·승인·rollback을 정의한다 | 검증 전에는 실행 가능한 범용 shell recipe가 아니라 문서화된 제안으로만 유지 |

### 시나리오에서 드러나는 가치

- **[추론]** 가장 잦고 값비싼 문제는 데이터 입력 자체보다 “어디에 있었고 다음에 무엇을 해야
  하는가”를 다시 구성하는 비용이다.
- **[추론]** Today는 새 source of truth가 아니라 여러 source의 제한된 projection이어야 한다.
- **[추론]** 개인/업무 통합은 저장소 통합이 아니라 탐색과 계획의 통합이어야 한다. 권한과 원문은
  영역별로 분리해야 유출 반경을 제한할 수 있다.
- **[제안]** 하루의 품질 지표를 “수집 개수” 대신 `미분류 항목 수`, `복귀까지 걸린 시간`, `출처가
  끊긴 task 비율`, `실패 후 수동 복구 가능 여부`로 둔다.

## 3. 전체 루프 분석

```text
외부/로컬 입력
     ↓
  [수집] ──→ Inbox(event + provenance)
     ↓
  [정리] ──→ personal/work 경계 · project/area · 중복 · reference/action
     ↓
  [계획] ──→ Today/Next · 일정 block · 의존성 · 완료 조건
     ↓
  [실행] ──→ 문서/terminal/editor/Agent/typed workflow
     ↓
  [검토] ──→ 결과 · diff · 결정 · 미해결 · 실패/복구 기록
     ↓
 [자동화] ─→ 반복 후보 → dry-run → 승인된 recipe → 관찰/중지/rollback
     └─────────────────────────────── 다시 Inbox/계획으로 feedback
```

### 단계별 입력, 출력과 품질 기준

| 단계 | 핵심 질문 | 최소 입력/출력 | 성공 기준 | 흔한 실패 |
|---|---|---|---|---|
| 수집 | 잊지 않고 원문으로 돌아갈 수 있는가 | 입력: file/API/webhook/CLI; 출력: immutable source ref와 received time | 10초 내 기록, offline 가능, 중복 식별 가능 | webhook 유실, 같은 항목 중복, 잘못된 계정 |
| 정리 | 행동인가, 자료인가, 버릴 것인가 | context, project/area, type, privacy, next action | 모호한 항목을 억지로 분류하지 않음 | AI 오분류, 개인/업무 교차 유출 |
| 계획 | 언제 무엇을 끝내면 되는가 | priority가 아닌 next action, due/start, dependency, done condition | 오늘 용량 안에서 실행 가능한 목록 | 외부 due와 로컬 계획 충돌, 과도한 계획 |
| 실행 | 올바른 맥락·권한에서 안전하게 실행하는가 | canonical project/context, action ID, preview, approval | 결과와 소유권·위치를 다시 찾을 수 있음 | 잘못된 repo/env, 자격 증명 만료, 부분 성공 |
| 검토 | 무엇이 바뀌고 무엇이 남았는가 | input snapshot, artifact/diff, outcome, decision, follow-up | 실패도 결과로 남고 다음 행동이 생김 | 성공으로 오인, terminal 로그 소실 |
| 자동화 | 반복 가치가 위험과 유지비보다 큰가 | 반복 증거, typed parameters, policy, recovery | idempotent/dry-run/중지/rollback 검증 | 무한 재시도, 파괴적 재실행, 조용한 drift |

### 실패·복구는 별도 기능이 아니라 루프의 상태

**[제안]** 모든 수집과 실행을 다음 공통 상태로 설명한다.

```text
received → staged → applied → reviewed
             ├→ blocked(auth/policy/conflict)
             ├→ retryable(network/rate-limit)
             └→ partial(surviving artifact + recovery instruction)
```

`failed` 하나로 뭉개지 않는다. retry 가능한 네트워크 실패와 사람이 판단해야 하는 충돌, 이미 일부
변경이 일어난 partial failure는 복구 방법이 다르다.

### 실패 모드와 복구 계약

| 실패 모드 | 감지 근거 | 기본 동작 | 복구·반론 |
|---|---|---|---|
| 오프라인/서비스 장애 | timeout, DNS, provider status | 로컬 capture·계획·terminal 실행은 계속하고 outbound를 queue | 자동 재시도는 read/idempotent 작업만; 오래된 결과에 `stale since` 표시 |
| webhook 누락·중복·순서 역전 | delivery ID, source event ID, reconciliation cursor | append 후 idempotency key로 projection 갱신 | webhook만 신뢰하지 않고 주기적 incremental poll로 대조; polling 비용 증가 |
| API rate limit | HTTP 429, `Retry-After` | adapter별 backoff와 next retry 표시 | global 작업을 막지 않음; 긴 지연 시 수동 sync 제공 |
| OAuth/Secret 만료 | provider auth error, expiry metadata | 해당 account adapter를 pause하고 plaintext를 log하지 않음 | 재인증 후 checkpoint부터 재개; 자동 권한 확대 금지 |
| 잘못된 personal/work context | account·vault·project policy 불일치 | write를 fail-closed, source와 destination을 재표시 | 편의는 줄지만 가장 중요한 유출 방지 경계 |
| 정리 충돌 | 로컬 edit와 remote revision/token 불일치 | 양쪽 원문 ref와 local draft를 보존 | 자동 last-write-wins 금지; 사람의 merge가 필요 |
| 실행의 부분 성공 | backend 생성 후 registry write 실패 등 | 살아 있는 path/session/resource ID와 exit를 보존 | compensating action은 제안만; 무조건 삭제하면 복구 자산을 잃음 |
| process/Agent 상태 불명 | 안정된 backend identity 부재 | `unknown/observed`로 표시, 완료를 추측하지 않음 | 상태가 덜 예뻐 보이지만 잘못된 stop보다 안전 |
| 파괴적 작업 중단 | apply/delete가 시작된 뒤 timeout | 자동 재시도 금지, provider 상태를 재조회 | plan과 실제 remote state를 비교한 뒤 수동 결정 |
| schema/state 손상 | parse/validation 실패 | last-known-good를 읽기 전용으로 열고 쓰기 중단 | backup 검증, migration dry-run, 명시적 restore 제공 |
| scheduler 중지/절전 | missed-run marker, lease expiry | 재개 시 실행 여부를 정책별 판단 | 모든 missed run을 몰아서 실행하지 않음; `skip/coalesce/run once` 선택 |
| 디스크 부족/쓰기 실패 | fsync/rename error | 성공으로 표시하지 않고 임시·기존 파일 위치를 보존 | 오래된 backup pruning은 preview와 retention 정책 필요 |

**[사실]** GitHub는 webhook 수신자가 secret을 검증하고 최소 event만 구독하며 delivery ID로 replay를
방지하고, 놓친 delivery를 redeliver하라고 권고한다. Slack Events API도 빠른 2xx 응답 뒤 처리를
분리하며 실패 delivery를 재시도한다. Google Drive notification은 변경 사실을 알릴 뿐 메시지 번호가
연속적이지 않고 channel이 만료되므로, 세 서비스 모두 “알림 수신 = 완전한 동기화”로 볼 수 없다.

**[추론]** 따라서 공통 adapter는 `fast acknowledge → durable inbox → async normalize → cursor 기반
reconcile` 계약을 가져야 한다. 다만 public webhook endpoint가 local-first 원칙과 충돌할 수 있으므로
초기 버전은 polling, 파일, CLI와 Slack Socket Mode 같은 outbound 연결을 우선할 수 있다.

## 4. 기능 후보 전체 지도

### A. 수집과 Inbox

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| 빠른 capture CLI/TUI | 생각·URL·할 일을 매일 여러 번 잃지 않음 | stdin/file 기반, offline, 기본 personal/work context 명시 | 핵심 |
| watched inbox directory | Markdown, PDF, screenshot, exported message를 서비스 비종속으로 수집 | 원본 이동보다 content hash·path ref 우선 | 핵심 |
| 공통 event envelope | 모든 adapter가 provenance, source ID, account, received time, privacy를 제공 | raw payload 보존 기간과 민감 필드 allowlist 필요 | 핵심 |
| 중복·replay 방지 | webhook/poll/수동 capture 중복을 줄임 | provider event ID + content hash, merge 이력 보존 | 핵심 |
| browser/mobile clipper | 이동 중 capture 마찰 감소 | 별도 endpoint와 device auth가 필요 | 있으면 좋음 |
| email/Slack/GitHub/Drive intake | 업무 요청을 한 inbox에서 triage | 최소 scope, metadata 우선, 원문 deep link | 첫 adapter 1~2개만 핵심 |
| OCR/attachment extraction | screenshot/PDF 검색 가능 | 원문 불변, 추출 결과는 파생 artifact | 있으면 좋음 |

### B. 정리, 문서와 지식

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| action/reference/defer/archive triage | 매일 inbox를 실행 가능한 상태로 바꿈 | 분류 없는 항목 허용, undo 가능한 metadata edit | 핵심 |
| personal/work area와 policy | 매일 계정·정보 유출 방지 | vault, credential, export destination을 분리 | 핵심 |
| project·area·topic 연결 | 코드, 문서, 일정, 메시지를 한 맥락에서 복귀 | 외부 객체 복제 대신 stable ref와 cached metadata | 핵심 |
| Markdown note + attachment manifest | Git/파일로 export·검색·복구 가능 | portable frontmatter, vendor ID는 별도 link table | 핵심 |
| 결정/회의/런북 template | 반복 문서 품질과 검토 속도 향상 | plain text source, template version 기록 | 있으면 좋음 |
| full-text search와 saved query | 매일 “어디 있었나” 탐색 감소 | 로컬 index는 재생성 가능해야 함 | 핵심 |
| semantic search/AI summary | 긴 자료 탐색 가속 | 원문 link·근거 표시, 민감 context별 모델 정책 | 있으면 좋음 |
| 문서 양방향 sync | 기존 Docs/Drive를 유지하면서 통합 | revision conflict, 서식 손실, 소유 block이 큰 비용 | 후순위 |

### C. 계획과 개인 운영

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| task의 next action/done condition | 매일 애매한 “프로젝트”를 실행 단위로 바꿈 | status보다 `다음 한 행동`을 필수에 가깝게 취급 | 핵심 |
| Today/Next/Waiting view | 매일 계획과 복귀 비용 감소 | Today는 projection, 원본 task를 복제하지 않음 | 핵심 |
| due/start/dependency | 주 여러 번 마감과 선행 조건 표현 | priority 숫자 남발 대신 blocked reason 표시 | 핵심 |
| 캘린더 busy block 연결 | 매일 가용 시간과 회의 충돌 확인 | CalDAV/서비스 API adapter, private detail 최소화 | 있으면 좋음 |
| recurring task | 주·월 반복 점검 누락 방지 | 완료 시 다음 occurrence 생성, timezone/DST 테스트 | 핵심 |
| 주간 review | 주 1회 stale project, waiting, 실패 run 정리 | local report와 checklist, 자동 archive 금지 | 핵심 |
| 목표/습관/시간 추적 | 장기 개인 운영 분석 | scope 팽창과 자기 감시 위험 | 후순위 |

### D. 코드·인프라 실행

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| project resume packet | 매일 branch, worktree, terminal, task, 관련 문서 복귀 | stable ID와 실제 provider 재검증 | 핵심 |
| safe worktree lifecycle | 주 여러 번 병렬 작업 충돌 감소 | Git porcelain 권위, dirty/locked/foreign 보호 | 핵심(현 구현 활용) |
| managed/observed Agent 구분 | 매일 AI 작업 위치와 stop 권한 오판 방지 | registry evidence와 scrape evidence 분리 | 핵심(현 구현 활용) |
| typed test/scan/plan | 주 여러 번 안전한 반복 실행 | fixed executable/argv, registered path, risk label | 핵심(현 구현 활용) |
| review packet | 주 여러 번 요구사항→diff→test→결정 연결 | raw output 복제보다 terminal/artifact ref | 핵심 |
| infra preflight | 위험 작업 전 account/region/cluster/state 확인 | read-only 우선, apply는 별도 승인과 provider-native plan | 핵심 |
| ephemeral dev environment | 재현성과 격리 향상 | container/VM 비용과 secret 전달 경계 큼 | 있으면 좋음 |
| 원격 runner | 장시간·대형 작업 편의 | cloud 의존, credential, 비용, 취소·소유권 복잡 | 후순위 |

### E. 반복 업무와 자동화

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| recipe catalog | 검증된 반복 동작을 재사용 | arbitrary shell runner 대신 typed input/capability | 핵심 |
| preview/dry-run/approval policy | 잘못된 쓰기와 개인/업무 교차 실행 방지 | action별 read/write/destructive risk와 승인 | 핵심 |
| durable run journal | 실패 후 “어디까지 됐나” 복구 | attempt, input hash, checkpoint, artifact, outcome | 핵심 |
| idempotency/retry policy | 네트워크 일시 실패 자동 복구 | read/idempotent만 자동; destructive는 재조회 후 승인 | 핵심 |
| OS-native scheduling | 주·일간 sync/review 실행 | Linux user timer/macOS LaunchAgent adapter, missed-run 정책 | 핵심 |
| 반복 패턴 탐지 | 수동 작업에서 자동화 후보 발견 | command 내용 수집보다 사용자가 표시한 recipe 횟수 | 있으면 좋음 |
| 자연어 자동화 생성 | 진입 장벽 감소 | 생성 즉시 실행 금지, typed schema와 테스트로 변환 | 후순위 |

### F. 외부 서비스와 연동

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| adapter catalog/health | 연결 상태·scope·마지막 sync를 한 곳에서 진단 | API/webhook/file/Git/CLI/MCP를 동등한 방식으로 기술 | 핵심 |
| account·credential reference | personal/work 계정 혼동 방지 | Secret 값이 아닌 ref, scope, expiry, owner metadata | 핵심 |
| incremental sync cursor | 반복 polling 비용과 누락 감소 | source별 opaque cursor, full reconcile 경로 | 핵심 |
| GitHub issue/PR adapter | 개발 업무 빈도와 현재 도구 적합성 높음 | assigned/review requested metadata와 deep link부터 | 첫 후보 |
| Slack intake adapter | 업무 요청 수집 가치 높음 | mention/saved item 등 최소 event, channel allowlist | 첫 후보 또는 실험 |
| Calendar/CalDAV adapter | 개인·업무 일정 통합 가치 | busy-only projection과 event write를 분리 | 있으면 좋음 |
| Drive/Docs adapter | 문서 변경·참조 수집 | notification은 힌트, changes API로 reconcile | 있으면 좋음 |
| MCP catalog/config/health/access | AI client 연결을 장비마다 재현 | stdio/HTTP, protocol version, client별 config ownership | 있으면 좋음 |
| webhook relay | near-real-time 수집 | public endpoint·TLS·운영 의존이 local-first와 충돌 | 후순위/선택 |
| export/import bundle | 서비스 탈출과 장비 복구 | Markdown/JSON/attachments + checksums + version | 핵심 |

### G. 보안, 운영과 복구

| 후보 | 사용자 가치·빈도 가설 | 경계와 구현 방향 | 단계 |
|---|---|---|---|
| `doctor` 통합 | 변경·장비 이동 때 원인 탐색 단축 | core/optional/disabled와 recovery 분리 | 핵심 |
| operation audit metadata | 매 실행의 주체·대상·결과를 설명 | secret/raw content 제외, local retention | 핵심 |
| backup/restore verify | 드문 사고의 손실 규모 감소 | 쓰기 전 backup + 정기 restore drill | 핵심 |
| schema migration dry-run | upgrade 중 state 손상 방지 | versioned migration, copy-on-write, rollback | 핵심 |
| privacy redaction policy | 화면·로그·AI 전송 경계 통제 | context별 allowlist, preview | 핵심 |
| capability/permission diff | integration 권한 확대 감지 | scope 변경 시 재승인 | 있으면 좋음 |
| encrypted cross-device sync | 여러 장비 연속성 | key recovery와 conflict가 제품 난도 급상승 | 후순위 |
| local metrics | 실제 빈도·fallback 근거 확보 | category/outcome/time만, command/content 제외, opt-in | 있으면 좋음 |

## 5. 반드시 필요한 핵심과 있으면 좋은 기능

### 핵심 기능 묶음

| 우선 | 기능 묶음 | 사용자 가치 | 빈도 근거 | 최소 완료 조건 |
|---:|---|---|---|---|
| P0 | context 경계(personal/work/account/vault) | 통합이 정보 유출로 바뀌지 않게 함 | 모든 수집·실행 | source/destination context 표시, 교차 write fail-closed |
| P0 | local Inbox + provenance + dedupe | 무엇이 어디서 왔는지 잃지 않음 | 매일 여러 번 | offline capture, source ref, received time, idempotency key |
| P0 | project/task/note 연결 + Today/Next | 분산된 요청을 다음 행동으로 변환 | 매일 | 외부 원문 deep link, next action, waiting/blocked reason |
| P0 | project resume + search | 중단한 코드·문서·terminal로 빠르게 복귀 | 매일 | project별 resumable location과 full-text query |
| P0 | typed action/recipe + preview/approval | 반복 실행의 속도와 위험 통제 | 주 여러 번 | arbitrary command 미노출, risk label, canonical target 재검증 |
| P0 | run journal + partial failure/recovery | 실패를 숨기지 않고 이어서 복구 | 모든 자동화 | checkpoint, surviving artifact, retryability, recovery instruction |
| P0 | adapter contract + health | API/MCP 한 방식에 종속되지 않음 | 매일 sync, 월간 setup | file/Git/API/webhook/CLI/MCP capability, cursor, scope, health |
| P0 | backup/export/migration/doctor | 장비 이동·upgrade·손상에서 사용자 통제 보장 | 낮은 빈도, 매우 큰 영향 | portable export, pre-write backup, restore verify, read-only doctor |
| P1 | recurring task + weekly review | 반복 업무와 stale project 누락 감소 | 주간/월간 | timezone 포함 recurrence, missed-run 정책, review checklist |
| P1 | 첫 외부 read adapter 1개 | 가설을 실제 사용으로 검증 | 업무일 매일 | GitHub 또는 Slack metadata intake, 최소 scope, manual reconcile |

핵심은 기능 수가 아니라 닫힌 루프다. 외부 항목 하나를 offline으로 수집하고, project/task로 정리하고,
실행 위치로 이동하고, 결과와 실패를 검토하며, 검증된 반복만 recipe로 승격할 수 있어야 한다.

### 있으면 좋은 기능

- Calendar busy projection과 time block
- browser/mobile capture, OCR, attachment text extraction
- AI 분류·요약·next-action 제안과 semantic search
- Drive/Docs 변경 수집과 제한된 양방향 update
- MCP server catalog, client별 config generation, handshake/health와 scope diff
- 반복 패턴 탐지, 템플릿, daily digest, 방해 최소화 notification routing
- encrypted cross-device sync, remote runner, 목표·습관·시간 분석

**[추론]** 이 기능들은 가치가 있을 수 있지만 핵심 루프, privacy boundary, 복구 계약이 없는 상태에서
먼저 만들면 데이터 복제와 자동화 표면만 늘어난다. 특히 AI 자동 분류, 양방향 문서 sync, 자연어
자동화, cross-device sync는 오류가 조용히 확산되는 영역이므로 후순위가 맞다.

## 6. 정보 구조 후보

### 사용자에게 보이는 구조

| 영역 | 답하는 질문 | 핵심 객체 |
|---|---|---|
| Today | 지금 무엇을 하고 무엇이 깨졌는가 | due/start task, busy block, resume, failed run |
| Inbox | 새로 들어온 것을 어떻게 처리할까 | capture/event, provenance, suggested classification |
| Projects | 원하는 결과와 현재 작업 위치는 어디인가 | project, outcome, next action, repo/worktree/session, links |
| Areas | 지속적으로 책임지는 개인/업무 영역은 무엇인가 | area, policy, account, recurring review |
| Library | 참고 자료와 결정은 어디 있는가 | note, document ref, bookmark, attachment, decision |
| Runs | 무엇을 실행했고 어디까지 됐는가 | recipe, attempt, checkpoint, artifact, outcome |
| Integrations | 무엇과 어떤 권한으로 연결됐는가 | adapter, account, scope, cursor, last sync, health |
| System & Recovery | 설치·state·backup이 건강한가 | doctor, migration, backup, export, restore drill |

Today에 모든 설정과 원문을 넣지 않는다. Inbox는 “안 읽은 알림함”이 아니라 처리되지 않은 입력만
보여준다. Library는 외부 문서를 복제하는 곳이 아니라 검색 가능한 local note와 원문 reference를
연결하는 곳이다.

### 내부 최소 객체 모델

```text
Context(personal|work, policy, vault/account refs)
  ├── Area ── Project ── Task
  │               ├── Note/Decision/ExternalRef
  │               ├── WorkLocation(repo/worktree/session/agent)
  │               └── Run(recipe/attempt/artifact/outcome)
  └── InboxItem(SourceEvent + provenance + classification state)

Adapter(account, capabilities, auth_ref, cursor, health)
Automation(recipe, typed_input, risk, schedule, retry/recovery policy)
```

**[제안]** 외부 객체의 ID와 cached title/status는 `ExternalRef`에 두고 원문은 source service가
소유한다. local projection은 언제든 adapter로 재구축 가능해야 한다. 사용자가 직접 만든 task/note와
결정 기록은 portable export에 반드시 포함한다.

## 7. 핵심 사용자 흐름 후보

### Flow 1 — 10초 capture에서 실행 가능한 task까지

1. context를 명시하거나 현재 안전한 기본값으로 `capture`한다.
2. 원문 URL/file과 provenance를 가진 InboxItem을 로컬에 먼저 저장한다.
3. dedupe 결과를 보여주되 자동 삭제하지 않는다.
4. 사용자가 `action/reference/defer/archive` 중 하나를 선택한다.
5. action이면 project/area, next action, done condition, due/start를 지정한다.
6. Today/Next에 projection하고 원문으로 돌아가는 link를 확인한다.

완료 기준: 외부 서비스가 없어도 1~5가 가능하고, 잘못 분류한 항목을 되돌릴 수 있다.

### Flow 2 — 아침 overview에서 중단 작업 복귀

1. Today가 stale external sync, 실패 run, due task, resumable terminal을 분리해 보여준다.
2. 사용자가 project를 선택하면 task·관련 문서·Git 상태·worktree·Agent evidence를 한 packet으로 본다.
3. 기존 stable location이면 jump하고, 없으면 backend 선택을 preview한 뒤 새로 연다.
4. 외부 상태가 stale이면 새로고침 실패를 숨기지 않고 cached 시각을 표시한다.

완료 기준: Workbench/Dashboard가 없어도 project path와 tmux/nvim 독립 경로가 안내된다.

### Flow 3 — 요청에서 Agent 구현과 review까지

1. GitHub/Slack item을 project task에 link하고 완료 조건을 작성한다.
2. clean/dirty, base branch, worktree 대상, context를 확인한다.
3. managed Agent를 시작하고 task ID와 stable terminal/worktree를 기록한다.
4. 종료 후 요구사항, diff, tests, Agent outcome, unresolved item을 review packet으로 만든다.
5. commit/push/merge 같은 외부 write는 별도 typed action과 사용자 승인으로 진행한다.

완료 기준: Agent가 실패해도 worktree와 terminal evidence가 남고 다음 행동을 만들 수 있다.

### Flow 4 — 인프라 점검과 변경

1. project와 업무 account/environment를 명시한다.
2. read-only preflight가 cloud account, region, cluster/namespace, Git/plan 상태를 표시한다.
3. allowlisted `test/scan/plan`을 실행하고 run journal과 terminal artifact를 연결한다.
4. apply/delete가 필요하면 현재 remote state를 재조회하고 영향과 rollback을 별도로 확인한다.
5. 결과를 task와 decision에 기록한다.

완료 기준: timeout 뒤 destructive action을 자동 재시도하지 않으며 provider-native 상태에서 복구한다.

### Flow 5 — 반복 작업을 자동화로 승격

1. review 중 사용자가 반복된 수동 흐름을 “automation candidate”로 표시한다.
2. 입력, canonical target, read/write risk, 예상 output, timeout, retry, recovery를 schema로 작성한다.
3. fixture와 dry-run에서 실패·중단·중복 실행을 검증한다.
4. 처음에는 수동 실행과 매번 승인으로 운영한다.
5. 사용 근거와 안정성이 생기면 OS-native schedule을 추가한다.
6. doctor에서 last/next run, missed run, pause 방법을 확인한다.

완료 기준: recipe를 끄거나 제거해도 원본 수동 절차와 데이터가 남는다.

### Flow 6 — 외부 adapter 연결과 해제

1. 필요한 capability(read issues, read mentions 등)를 먼저 선택한다.
2. account/context, scopes, auth reference, 저장될 metadata와 retention을 preview한다.
3. 연결 뒤 small sync와 cursor/reconcile을 검증한다.
4. health에 last success, last error, next retry, stale 상태를 표시한다.
5. disable은 새 sync만 멈추고 local user-authored task/note를 삭제하지 않는다.
6. disconnect 시 token revoke 안내와 cached source metadata 삭제/보존 선택을 제공한다.

완료 기준: service를 제거해도 portable user data와 원문 URL 목록을 export할 수 있다.

## 핵심 결론

1. 제품의 중심은 “모든 서비스를 복제하는 Dashboard”가 아니라 local-first 운영 코어다. 핵심 가치는
   provenance가 있는 수집, personal/work 경계, 다음 행동, 안전한 실행, 실패 후 복구의 닫힌 루프다.
2. 현재 Workbench의 project resume, managed/observed 구분, typed workflow, backup, doctor 계약은 좋은
   기반이다. 이를 문서·계획·정보 수집까지 확장하되 외부 원문과 Git의 권위를 빼앗지 않아야 한다.
3. MCP는 유용한 integration surface지만 stdio와 Streamable HTTP를 가진 특정 protocol이다. API,
   webhook, file, Git, CLI, CalDAV를 포함하는 adapter 계약 아래 한 종류로 다루는 편이 비종속성과 복구에
   맞다.
4. 자동화의 성공은 “자동 실행됐다”가 아니라 target 재검증, typed input, idempotency, partial outcome,
   중지와 수동 복구가 설명되는 것이다.
5. 우선순위의 빈도 근거는 아직 가설이다. 기능 확대 전에 실제 일주일의 capture, resume, fallback,
   실패 run을 metadata-only로 관찰해야 한다.

## 채택 권고

1. 첫 vertical slice로 `local capture → Inbox triage → project/task link → Today → project resume →
   review`를 만든다. 외부 integration 없이도 파일과 CLI로 완주돼야 한다.
2. personal/work `Context`를 최상위 보안 객체로 먼저 정의한다. account, vault, adapter, export destination,
   execution environment의 교차 write는 명시적 정책 없이는 거부한다.
3. adapter v1은 `capabilities, account/context, auth_ref, cursor, provenance, idempotency key, health,
   reconcile, disable/export` 계약만 정의한다. generic plugin runtime이나 범용 proxy는 만들지 않는다.
4. 첫 외부 read adapter는 현재 개발 흐름과 맞는 GitHub assigned/review-requested 후보를 우선 검증한다.
   Slack은 요청 빈도가 더 높다는 실제 관찰이 있으면 mention/saved-item 최소 범위로 선택한다.
5. 자동화 v1은 현 Workbench typed workflow를 일반화하지 말고, recipe catalog와 durable run journal,
   preview/approval, OS별 scheduler adapter를 작은 범위에서 추가한다. destructive remote action은 제외한다.
6. 매 release에서 export→새 빈 state로 restore하는 drill을 대표 fixture로 수행하고, Dashboard가 없어도
   CLI/Markdown/tmux/nvim fallback을 문서화한다.
7. 1주 관찰 후 다음을 raw evidence로 기록한다: 하루 capture 수, triage까지 걸린 시간, project resume
   경로, source별 중복·실패, manual fallback, 반복 recipe 후보. 내용이나 명령 원문은 수집하지 않는다.

## 반론

- **“통합 코어가 또 하나의 inbox와 task manager를 만든다.”** 맞다. 외부 source를 전부 복제하거나
  양방향 sync하면 유지비가 가치보다 커질 수 있다. 그래서 local inbox는 미처리 입력과 사용자 작성
  task만 소유하고, 외부 원문은 reference로 남기는 제한이 필요하다.
- **“terminal-first 사용자에게 Today UI는 불필요하다.”** Dashboard 사용 빈도 증거가 아직 없으므로
  타당한 반론이다. 같은 query와 action을 CLI/TUI가 먼저 제공하고 Dashboard는 projection client로
  유지해야 한다.
- **“파일과 Git만으로 충분하다.”** portability와 복구에는 강한 대안이다. 다만 webhook dedupe,
  scheduler lease, cross-process write, relation query는 구조화 state가 유리하다. 따라서 파일 export를
  보장하되 내부 저장 형식은 실제 동시성 요구가 생긴 뒤 선택해야 한다.
- **“처음부터 Slack·Calendar·Drive를 연결해야 통합 가치가 보인다.”** 외부 가치는 빨리 보이지만 auth,
  scope, conflict, webhook 운영이 동시에 들어와 핵심 루프 검증을 방해한다. read-only adapter 하나로
  vertical slice를 증명한 뒤 넓히는 편이 안전하다.
- **“AI가 자동으로 분류·계획해야 한다.”** 제안 품질은 유용할 수 있지만 개인/업무 오분류와 근거 없는
  action 생성의 비용이 크다. AI output은 provenance를 가진 suggestion으로만 저장하고 사용자가
  확정해야 한다.
- **“복구 계약과 승인 때문에 자동화가 느리다.”** 읽기 전용·idempotent 동작은 승인 빈도를 낮출 수
  있다. 반대로 인프라 변경, 외부 문서 overwrite, 메시지 전송은 속도보다 잘못된 실행의 비용이 크다.

## 불확실성

- 실제로 매일 사용하는 개인 업무 source, 업무 Slack/GitHub 빈도, 첫 캘린더 provider가 확인되지 않았다.
- Workbench가 기본 경로인지 선택적 ops UI인지, CLI와 Dashboard 중 어느 쪽이 일상 primary인지 사용
  관찰이 없다.
- local structured store를 기존 TOML/JSON registry로 확장할지 SQLite 같은 transactional index로
  옮길지 결정 근거가 부족하다. 동시 writer와 query 규모를 먼저 측정해야 한다.
- 모바일 capture와 여러 장비 간 sync가 필수인지, Git 기반 수동 동기화로 충분한지 알 수 없다.
- 업무 서비스의 조직 정책이 OAuth app, webhook endpoint, Slack Socket Mode, local token 저장을
  허용하는지 확인하지 않았다.
- Calendar에서 busy-only면 충분한지, event 생성·수정까지 필요한지 알 수 없다.
- AI processing을 완전 로컬로 제한할지, context별로 외부 모델을 허용할지 privacy 정책이 없다.
- OS sleep, timezone/DST, 장기 offline, credential rotation, state corruption에 대한 실제 장비 recovery
  drill은 아직 실행하지 않았다.

## 출처

### 저장소 내부 근거

- [root README](../../README.md), [제품 기획서](../PRODUCT-PLAN.md), [plan 안내](../README.md) — 제품
  정의, 책임 구조, 원칙과 미결정. 확인일 2026-08-10.
- [현재 시스템](current-system.md), [저장소 기준선](repository-baseline.md),
  [검증 기준선](validation-baseline.md), [후보 과제](backlog-and-open-questions.md),
  [문서 인벤토리](document-inventory.md) — 현재 기능, 검증 범위, drift와 사용 증거 부족. 확인일
  2026-08-10.
- [Workbench README](../../workbench/README.md),
  [Dashboard](../../workbench/docs/dashboard.md), [Agent ownership](../../workbench/docs/agents.md),
  [Worktree safety](../../workbench/docs/worktrees.md), [Typed workflows](../../workbench/docs/workflows.md),
  [Secrets](../../workbench/docs/secrets.md), [Doctor](../../workbench/docs/doctor.md) — state, ownership,
  action, security, backup과 failure contract. 확인일 2026-08-10.
- [binbox README](../../binbox/README.md), [nvim README](../../nvim/README.md),
  [cmux-config README](../../cmux-config/README.md),
  [cmux workflows](../../cmux-config/docs/workflows.md) — 독립 terminal 경로, 개발·인프라 command와
  client 역할. 확인일 2026-08-10.

### 외부 공식 문서·1차 자료

- GitHub, [Best practices for using webhooks](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks) — 최소 event 구독, secret, 빠른 응답, delivery ID, redelivery. 확인일
  2026-08-10.
- GitHub, [REST API endpoints for issues](https://docs.github.com/en/rest/issues) — authenticated user의
  assigned issue 조회와 issue 관리 API 범위. 확인일 2026-08-10.
- Slack, [Events API](https://api.slack.com/apis/connections/events-api)와
  [Rate limits](https://api.slack.com/docs/rate-limits) — 2xx 응답, retry, rate limit과 `Retry-After`.
  확인일 2026-08-10.
- Google, [Google Drive resource change notifications](https://developers.google.com/workspace/drive/api/guides/push) — HTTPS watch channel, 만료·갱신, 비연속 message number, notification 뒤 changes 조회 필요성.
  확인일 2026-08-10.
- Model Context Protocol, [Transports, protocol version 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) — stdio와 Streamable HTTP, localhost binding과 Origin 검증. 확인일 2026-08-10.
- Model Context Protocol, [Authorization, protocol version 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) — OAuth 2.1 계열 discovery, audience-bound token과 secure storage 요구. 확인일 2026-08-10.
- Git, [git-worktree documentation](https://git-scm.com/docs/git-worktree.html) — stable porcelain output,
  clean remove, lock/prune/repair 계약. 확인일 2026-08-10.
- IETF, [RFC 4791: CalDAV](https://www.rfc-editor.org/info/rfc4791/) — WebDAV 기반 calendar access 표준.
  확인일 2026-08-10.
- Apple, [Creating Launch Daemons and Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) — per-user LaunchAgent와 on-demand/timed background job. 확인일 2026-08-10. 이 자료는 archive 문서이므로 최신 macOS 세부 동작은 실제 장비 smoke가 필요하다.
