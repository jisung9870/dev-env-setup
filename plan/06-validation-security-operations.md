# 검증·보안·운영 기준

## 목적

계획의 완료 주장을 검증할 공통 기준을 정의한다. 각 Phase는 관련 항목을 실제 command output 또는
test artifact로 증명해야 한다.

## 검증 순서

```text
contract/fixture test
→ changed repo targeted test
→ lint/static check
→ cross-repo integration
→ clean-machine/profile smoke
→ doctor and rollback check
```

## Test matrix

| 영역 | 최소 검증 | 성공 기준 |
|---|---|---|
| dev-env manifest | schema, order, duplicate, missing command | invalid input non-zero와 위치 표시 |
| bootstrap/update | clean, dirty, offline, child failure | partial failure가 성공으로 보고되지 않음 |
| binbox JSON | fixture, stdout purity, exit code | schema fixture와 완전 일치 |
| project migration | `~`, 공백, `=`, dead path | dry-run과 apply 결과 일치 |
| backend detect | cmux/tmux/shell/SSH 조합 | explicit option 우선, safe fallback |
| Windows backend | `wt.exe`, WSL interop, missing profile, path | cmux 없이 open/fallback/recovery 동작 |
| worktree | duplicate, dirty, conflict, remove | unsafe operation 거부 |
| Agent registry | launch/list/jump/stop/crash | stable task ID, stale state 탐지 |
| cmux config | build drift, action reference, sensitive scan | generated source 일치 |
| LazyVim client | async, timeout, bad JSON, missing CLI | editor block 없음, fallback 설명 |
| Dashboard | bind, shutdown, action auth, responsive | loopback-only, listener cleanup |
| cross-version | old client/new core, new client/old core | version mismatch 명확히 거부/안내 |

## Platform scenarios

### macOS + cmux

- `wb open --backend cmux`
- cmux action/generated workspace
- in-app browser Dashboard
- native Agent tab registration/jump

### macOS/Linux + tmux

- tmux session create/reuse
- pane metadata
- detach/attach 후 task/session correlation
- cmux 없이 doctor와 project/worktree 사용

### WSL

- XDG path와 symlink
- browser open fallback
- tmux and LazyVim client
- macOS-only capability를 optional/unavailable로 표시
- Windows Terminal profile과 `wt.exe` interop detect
- WSL project path를 Windows path로 조용히 오해하지 않음

### Windows native

- `wb.exe projects/worktrees/agents/doctor/dashboard`
- `wt.exe` new/existing window와 starting directory
- WSL profile open과 missing profile guidance
- cmux absent가 required failure가 아님
- Bash/binbox provider는 WSL adapter 또는 explicit unavailable

### SSH

- auto backend가 cmux를 선택하지 않음
- tmux 또는 shell 사용
- Dashboard는 explicit 요청 전 자동 실행하지 않음

## 실패 시나리오

| 실패 | 기대 동작 | 복구 |
|---|---|---|
| config parse 실패 | 변경하지 않고 field 위치와 오류 반환 | backup/config 수정 |
| state write 중 crash | 이전 valid state 유지 | temp 정리, backup restore |
| cmux unavailable | cmux action만 unavailable | tmux/shell 명시 |
| Windows Terminal unavailable | WT action만 unavailable | PowerShell/shell 또는 WSL tmux |
| WSL distribution/profile 불일치 | 사용 가능한 profile과 설정 guidance | machine-local profile 수정 |
| tmux server 없음 | create 가능 여부 또는 unavailable 표시 | shell fallback |
| Agent process 종료 | task를 stale/failed로 reconcile | acknowledge/archive |
| repo dirty | update/migration 중단 | commit/stash 후 재실행 |
| schema mismatch | 해석 중단, version 표시 | client/core update |
| Dashboard port 충돌 | 다른 port 선택 또는 명확한 실패 | `--port 0` |
| child setup 실패 | aggregate non-zero | 해당 child doctor/setup |

## 보안 체크리스트

### Local API와 Dashboard

- [ ] 기본 listen address가 loopback-only인가
- [ ] external interface listen은 기본/자동으로 불가능한가
- [ ] state-changing request가 허용된 local origin과 method를 검증하는가
- [ ] arbitrary shell text를 받지 않는가
- [ ] registered command ID와 argument schema만 실행하는가
- [ ] secret/token 원문을 response/UI/log에 노출하지 않는가
- [ ] listener 종료와 stale socket 정리가 검증됐는가

### Process와 command 실행

- [ ] shell string 대신 argument 배열을 사용하는가
- [ ] path와 backend reference를 실행 직전 다시 검증하는가
- [ ] timeout과 cancellation을 지원하는가
- [ ] stop/remove 같은 변경 action이 정확한 등록 대상을 요구하는가
- [ ] Terraform apply/destroy의 기존 보호 절차를 보존하는가

### File과 state

- [ ] config와 state를 분리하는가
- [ ] state file permission이 현재 사용자로 제한되는가
- [ ] atomic write와 backup을 사용하는가
- [ ] committed file에 runtime state, socket, browser history, token이 없는가
- [ ] migration 실패 시 원본을 보존하는가
- [ ] Windows native와 WSL state/path를 암묵적으로 합치지 않는가

## 2차 영향

### 중앙 state 장애

project/Agent state를 중앙화하면 UI 일관성은 좋아지지만 state file이 손상될 때 여러 client가 동시에
영향을 받는다. 따라서 atomic write, backup, reconcile command가 architecture의 필수 기능이다.

### Schema 변경 전파

schema 변경은 cmux generator, LazyVim client, Dashboard를 동시에 깨뜨릴 수 있다. version mismatch를
명확히 탐지하고 producer-first → compatibility consumer → fallback removal 순서를 지켜야 한다.

### UI 경계 확장

Dashboard/Desktop UI는 trusted shell-only 환경보다 공격 surface를 넓힌다. loopback-only만으로 모든
위험이 없어지지 않으므로 arbitrary command 입력, secret 표시, destructive action 검증을 core에서
제한해야 한다.

### 자동화의 편의와 위험

`wb open`과 Agent launch 자동화가 쉬워질수록 잘못된 profile/backend/path를 빠르게 확산할 수 있다.
명시적 option 우선, dry-run/preflight, project ID/path 표시가 필요하다.

## 운영 지표와 관찰

고정된 주/일 수를 임의로 정하지 않는다. 각 단계의 관찰은 실제 개인 workflow의 대표 사건을 포함한다.

| 확인 항목 | 수집 위치 | 확인 시점 | 수용 기준 |
|---|---|---|---|
| `contract_test_failures` | CI/aggregate test | 모든 변경 직후 | 0 |
| `doctor_required_failures` | `wb doctor` | bootstrap/update 후 | 0 |
| `fallback_invocations` | doctor/event log | 대표 project/Agent 사용 후 | legacy 제거 전 0 확인 |
| `state_recovery_failures` | migration/reconcile test | schema 변경 시 | 0 |
| `backend_launch_failures` | event log | cmux/tmux/shell smoke | 원인이 설명되지 않은 실패 0 |
| `windows_backend_failures` | event log | WT native/WSL smoke | recovery guidance 없는 실패 0 |
| `stale_agent_tasks` | `wb agents list` | Agent 종료/reconnect 후 | reconcile되지 않은 항목 0 |
| `generated_config_drift` | cmux CI | config 변경 시 | 0 |

관찰 단계:

1. 즉시: 변경 command와 targeted test
2. 집중: project open, Agent start/wait/jump/stop, worktree create/remove
3. 단기: tmux detach/attach, cmux restart, shell restart
4. 최종: 다른 장비 또는 clean profile에서 bootstrap/update/doctor

각 Phase는 관련 대표 사건이 끝난 뒤에만 완료 처리한다.

## 수용과 롤백

### 공통 수용

- required test와 doctor failure 0
- 기존 supported workflow 또는 documented compatibility path 동작
- source repo clean
- schema/docs/help/completion 일치
- backup/rollback command를 실제 fixture 또는 safe sandbox에서 검증

### 공통 롤백 발동

- 기존 project 목록이 누락되거나 잘못된 path로 열림
- dirty worktree/session이 자동 제거 또는 덮어쓰기 위험에 놓임
- Agent stop/jump가 다른 process를 대상으로 함
- schema mismatch가 조용히 잘못 해석됨
- Dashboard가 loopback 밖에 listen하거나 secret을 노출
- bootstrap partial failure가 성공으로 보고됨

롤백 후 원인과 재진입 조건을 해당 Phase 문서와 결정 기록에 갱신한다.

## 문서 품질 검수 기록

이 계획 패키지를 변경할 때 다음을 확인한다.

- 범위: 네 repo, workbench core, cmux/Windows Terminal/tmux/LazyVim/Web UI, 장비 재개 절차 포함
- 근거: repository fact와 권고/미확인 구분
- 결정: 기본안, 대안, 재검토 조건 명시
- 실행: Phase별 dependency, 수용, rollback 명시
- 무결성: 내부 Markdown link와 heading, code block, file 존재 검사

HTML은 이 repository의 기존 문서 관례가 Markdown이므로 생성하지 않는다. UI visual prototype은 구현
Phase에서 별도 artifact로 관리한다.

### 2026-08-04 작성 검수 결과

| 루브릭 | 결과 |
|---|---|
| 1. 범위 충실성 | 통과 |
| 2. 근거 규율 | 통과; repository fact, 권고, 미확인 범위를 분리 |
| 3. 결정 품질 | 통과; 대안, 기본안, 조건, 재검토 기준 포함 |
| 4. 관점의 완전성 | 2/2 |
| 5. 실행 준비도 | 2/2 |
| 6. 구조와 가독성 | 2/2 |
| 7. 산출물 무결성 | 통과 |

검사 증거:

- Markdown 11개 UTF-8 read와 렌더 parser 통과
- relative link target 17개 검사, broken link 0
- unbalanced fenced code block 0
- `git diff --check` 통과

`markdownlint` executable은 현재 검수 환경에 없어 실행하지 못했다. 대신 bundled `marked` parser로
모든 Markdown을 HTML string으로 렌더하고 H1과 비정상 placeholder 출력을 검사했다.
