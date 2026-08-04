# 구현 로드맵

## 실행 원칙

- Phase를 건너뛰지 않는다. downstream UI보다 upstream contract를 먼저 검증한다.
- 각 Phase는 독립적으로 rollback 가능한 작은 commit/PR로 나눈다.
- 기존 workflow를 제거하기 전에 compatibility path의 실제 사용 여부를 doctor로 확인한다.
- 새 dependency는 현재 toolchain으로 해결할 수 없는 요구가 확인된 경우에만 추가한다.
- source repo가 dirty하면 자동 update/migration을 중단한다.

## 전체 순서

```text
Phase 0  기존 계약 고정
   ↓
Phase 1  binbox 구조화 read API
   ↓
Phase 2  workbench core
   ↓
Phase 3  cmux/Windows Terminal/LazyVim clients와 Dashboard
   ↓
Phase 4  중복 제거와 책임 정리
   ↓
Phase 5  별도 Desktop UI 필요성 평가
```

## Phase 0 — 기존 계약 고정

### 목적

새 core를 만들기 전에 현재 동작과 cross-repo contract를 자동 검증한다.

### 작업

1. `dev-env-setup`에 aggregate contract test entrypoint 추가
2. cmux가 참조하는 `bb <tool>` 존재 검사 강화
3. cmux `workspace.*.commandName`이 실제 command를 가리키는지 검사
4. binbox sessionizer fixture와 LazyVim parser 결과 비교
5. compatible repo commit snapshot 추가
6. bootstrap/update partial failure를 non-zero로 반환
7. ADR-005에 따라 runtime link owner 정리
8. cmux generated config와 sensitive scan CI 추가
9. platform-aware repo selection과 doctor severity를 추가해 WSL/Linux에서 cmux setup을 자동 제외하고
   missing cmux를 optional/skipped로 판정

### 구현 순서

```text
contract fixtures
→ read-only checker
→ CI
→ failure semantics
→ platform selector/doctor severity
→ link owner migration
→ repo snapshot doctor
```

### Phase 0 고정 형식

Repo snapshot은 dependency 없이 Bash에서 읽을 수 있는 `locks/repos.lock`을 사용한다.

```text
# schema-version: 1
binbox 25f20c24fe07d79dfbaa5e11f574b28cdba02210
nvim f12e9c0963aef7fe136381841be9a1de5b627a79
cmux-config 042074805d0faf85a15ba641261051bb70589450
```

규칙:

- field는 `local-name full-40-char-sha` 두 개다.
- manifest에 없는 name, duplicate name, SHA 형식 오류는 검사 실패다.
- snapshot mismatch는 report-only이며 checkout/reset하지 않는다.
- Workbench repo가 Phase 2에서 추가되면 같은 형식으로 행을 추가한다.

Platform 선택도 Phase 0에서 dependency 없이 읽을 수 있는 `platforms/<id>.repos`로 고정한다.

```text
# schema-version: 1
binbox required
nvim required
cmux-config optional
```

지원 ID는 `macos`, `linux`, `windows-wsl`이다. macOS에서는 cmux가 `optional`, Linux와
Windows/WSL에서는 `disabled`다.

선택 우선순위:

1. `--platform <id>` explicit option
2. test/CI용 `WB_PLATFORM=<id>` environment
3. `WSL_INTEROP` 또는 kernel release의 Microsoft marker로 `windows-wsl` 감지
4. `uname -s`의 Darwin/Linux mapping
5. 알 수 없으면 변경 없이 실패하고 지원 ID를 출력

row 의미:

- `required`: 선택하고 clone/setup/doctor 실패를 aggregate failure로 처리
- `optional`: 기본 선택하지만 `--without <repo>`로 제외 가능; missing/unavailable은 warning
- `disabled`: 기본 제외; explicit repo name으로 실행할 때만 시도하고 결과를 명시

`bootstrap.sh`, `upgrade.sh`, `doctor.sh`는 하나의 read-only selector helper를 사용해 같은
platform ID, repo set, severity를 계산한다. selector 결과는 `--show-selection`으로 command 실행 없이
출력할 수 있어야 한다. platform file에 없는 repo, duplicate row, 잘못된 severity는 실패다.

Contract harness는 `tests/contract-test.sh` 하나를 aggregate entrypoint로 사용한다. 내부에서 Python 3을
JSON parse에 사용할 수 있으며, 필요한 child repo가 없으면 bootstrap guidance와 함께 실패한다.

Sessionizer fixture corpus:

```text
tests/fixtures/sessionizer/
├─ dirs                 comment, blank, parent root, =direct, dead path
└─ expected-projects    normalized project path를 정렬한 결과
```

test는 temporary root에 일반 project, 공백이 있는 project, direct project, dead path를 만든다.
Phase 0에서 `bb tm projects --plain` 관찰 command와 LazyVim headless fixture helper를 추가하고 두 출력과
`expected-projects`를 정렬 비교한다. Phase 1 JSON API는 같은 parser를 재사용한다.

Runtime link owner:

- parent 유지: `~/binbox` alias
- child 소유: `~/.local/bin/bb`, shell rc, `~/.config/nvim`, `~/.tmux.conf`, cmux/app-support files
- migration 후 nvim과 cmux manifest `link_target`은 비운다.

### 수용 기준

- 존재하지 않는 `bb` command를 cmux가 참조하면 test 실패
- cmux action의 command reference가 없으면 test 실패
- sessionizer fixture의 project set이 binbox와 LazyVim에서 동일
- child setup 하나가 실패하면 bootstrap/update가 exit 0으로 끝나지 않음
- doctor가 snapshot commit과 현재 checkout 차이를 표시
- 기존 clean machine bootstrap dry-run 결과가 보존됨
- WSL/Linux profile에서 cmux가 disabled/skipped로 보고되고 bootstrap 전체 실패를 만들지 않음
- macOS에서도 cmux missing/unavailable은 warning이며 required aggregate failure가 아님
- bootstrap/upgrade/doctor의 `--show-selection` 결과가 동일
- Windows Terminal + WSL에서 cmux 없이 bootstrap/doctor와 baseline workflow가 동작

### 롤백

- 기존 `repos.txt`와 child setup command를 compatibility mode로 유지
- platform profile 적용 전 WSL 호환 경로로 `./bootstrap.sh binbox nvim` 유지
- snapshot mismatch는 자동 checkout하지 않고 report-only
- link owner 변경 전 기존 target을 timestamp backup

### 완료 증거

- 관련 test output
- 각 repo의 clean `git status`
- sample doctor output
- 변경된 contract와 consumer 목록

## Phase 1 — 구조화 read API

### 목적

file parsing과 화면 scraping 의존을 줄일 machine-readable interface를 만든다.

### 작업

`binbox`에 다음을 추가한다.

```bash
bb tm projects --json
bb tm sessions --json
bb agents --json
bb doctor --json
```

LazyVim project picker는 JSON API를 우선 사용하고 기존 sessionizer parser를 fallback으로 유지한다.

### 수용 기준

- `bb tm projects --json`이 stable schema envelope 사용
- path에 공백, `~`, `=` direct entry, dead entry fixture 처리
- tmux가 없을 때 sessions/agents command가 명확한 capability error 반환
- JSON stdout에 log가 섞이지 않음
- macOS와 Linux CI 및 Windows Terminal 안 WSL의 `bb` contract smoke 통과
- LazyVim picker와 CLI project ID/path 집합이 같음
- `bb`가 없거나 schema가 다른 경우 LazyVim이 fallback하고 이유 표시

### 롤백

- LazyVim feature flag로 API client 비활성화
- 기존 parser와 `bb agents` text UI 유지

### 2026-08-04 구현 기록

- binbox `25f20c2`: projects/sessions/agents/doctor schema v1 JSON read API
- nvim `bfca6e7`, `f12e9c0`: 비동기 JSON 우선 project picker와 help 문서
- WSL 검증: `tests/json-contract-test.sh`, `tests/contract-test.sh`, `bb check`, Stylua 통과
- compatibility: 기존 text UI와 sessionizer fallback 유지
- 완료 대기: 기존 binbox macOS/Linux CI는 원격 push 이후 새 `tests/json.bats`를 실행해야 함

## Phase 2 — Workbench core

### 고정 구현 기준

- 언어: Go 1.25.12
- 배포: macOS/Linux/Windows single binary
- initial schema version: 1
- 초기 runtime: daemon 없는 CLI process
- HTTP: standard library local server, loopback-only
- release: 초기에는 source build와 dev-env bootstrap; 안정화 후 GitHub release 검토

Phase 2 첫 commit에서 `go.mod`, supported OS/architecture, config parser dependency를 기록한다. 이 선택은
core architecture를 다시 결정하는 단계가 아니라 고정 기준을 코드로 선언하는 단계다.

### Slice 2A — config와 project registry

- XDG config/state path
- project/profile schema
- config validation
- `wb projects list|show|add|remove`
- sessionizer import `--check`와 `--apply`

수용 기준:

- canonical path 중복 차단
- invalid config line/field 위치 표시
- remove가 repo를 삭제하지 않음
- migration 전 backup과 dry-run diff 제공

### 2026-08-04 Slice 2A 로컬 구현 기록

- workbench `84ba289`: Go 1.25.12 module, supported target, BurntSushi TOML v1.4.0 선택 근거와 checksum 고정
- workbench `7ddc5d3`: schema-v1 project registry, config/profile validation, JSON read envelope,
  sessionizer `--check`/`--apply`, atomic replacement와 state backup
- 검증: `go test -race ./...`, `go vet ./...`, Linux build, macOS amd64/arm64 및 Windows amd64 cross-build 통과
- safety: canonical path/ID conflict는 exit 4, remove는 registry만 변경, migration source와 이전 registry backup 유지
- 원격 상태: 사용자가 push를 추후 수행하기로 하여 remote 생성, GitHub Actions, setup platform manifest와
  `locks/repos.lock` 연결은 보류
- 계획 차이: Phase 1 원격 CI 게이트를 완료 처리하지 않았지만, 사용자 명시 승인으로 Slice 2A 로컬 구현만 선행
- 다음 로컬 작업: Slice 2B adapter contract와 shell backend

### Slice 2B — backend와 open

- headless adapter contract와 CLI behavior
- shell backend
- tmux backend
- cmux backend
- Windows Terminal/WSL backend
- capability detection
- `wb open`

수용 기준:

- explicit `--backend`가 auto/profile보다 우선
- cmux가 없어도 shell/tmux 동작
- Windows에서 cmux가 required capability로 판정되지 않음
- Windows native `wt.exe`와 WSL Windows interop 경로를 구분
- Windows Terminal profile이 없거나 이름이 다르면 shell/tmux fallback과 recovery guidance
- SSH에서 cmux auto-select하지 않음
- backend command 실패 시 stderr/exit/reference 보존

### Slice 2C — worktree

- list/create/remove
- stable worktree ID
- dirty/conflict safety

수용 기준:

- 같은 branch 중복 worktree 차단
- dirty remove 거부
- Git porcelain 결과와 target path 일치 확인
- branch 삭제는 별도 option과 확인 필요

### Slice 2D — Agent registry

- task ID와 state model
- Codex/Claude launch adapter
- tmux pane metadata
- cmux backend reference
- list/show/jump/stop

수용 기준:

- launch 직후 task registry에서 조회 가능
- cmux, tmux, Windows Terminal/WSL task가 같은 schema로 표시
- 등록되지 않은 process를 stop하지 않음
- legacy scraping state에는 source 표시

### 롤백

- state migration backup
- `wb` 실패 시 기존 `bb tm`, cmux action, Windows Terminal/WSL shell, direct Agent command 사용 가능
- backend별 feature flag

## Phase 3 — Clients와 Dashboard

### Slice 3A — cmux

- `Open Workbench Dashboard`
- `Open Project`, `Start Agent`, `Show Agents`, `Run Doctor`
- project/workflow generated fragments
- generated reference validation

### Slice 3B — Windows Terminal

- Slice 2B adapter를 사용하는 user-facing action과 profile UX
- machine-local profile name/GUID와 WSL distro 설정·오류 안내
- native path와 explicit WSL path를 구분한 project open flow
- new/existing window, tab, optional pane integration smoke
- Dashboard default browser open
- cmux 없는 Windows smoke test

### Slice 3C — LazyVim

- project/Agent/worktree/doctor picker
- async command 실행
- schema/error/fallback UX
- help 문서와 keymap contract update

### Slice 3D — Dashboard

- loopback local server
- Projects, Agents, Worktrees, Changes, Doctor 화면
- selected task detail와 jump/test/stop action
- responsive/keyboard accessibility

### 수용 기준

- project 한 번 등록로 사용 가능한 cmux, Windows Terminal, LazyVim client에 동일하게 표시
- cmux/tmux Agent가 같은 task list에 표시
- Windows Terminal/WSL Agent도 같은 task schema에 표시
- Dashboard가 internal state file을 직접 parse하지 않음
- Dashboard 종료 후 listener가 남지 않음
- UI에서 arbitrary shell command를 만들 수 없음
- core/clients schema compatibility test 통과

### 롤백

- generated cmux fragment 제거 후 committed known-good `cmux.json` 사용
- Windows Terminal integration disable 후 PowerShell 또는 WSL tmux/shell 사용
- LazyVim plugin/client disable
- Dashboard 없이 CLI 사용

## Phase 4 — 중복 제거와 책임 정리

### 작업

- cmux의 중복 project root registry 제거
- LazyVim direct sessionizer parser 제거 검토
- legacy Agent screen scraping 제거 검토
- `lazyvim-config`의 OS/runtime install을 dev-env profile로 점진 이전
- hardcoded path를 profile/project manifest로 이전
- parent/child runtime link owner 문서와 코드 일치

### 제거 조건

legacy path는 다음이 모두 충족될 때만 제거한다.

- 지원 장비가 새 schema/client를 사용
- doctor가 fallback 호출 여부를 탐지
- 대표 사용 주기 동안 fallback 호출이 없음
- rollback release/tag 또는 documented recovery path 존재

대표 사용 주기는 고정 날짜가 아니라 실제 개인 workflow의 프로젝트 open, Agent 실행, tmux reconnect,
새 장비 또는 clean profile smoke를 포함해야 한다.

## Phase 5 — 별도 Desktop UI 평가

다음 신호를 기록한다.

- 동시에 운영하는 Agent/worktree 수와 Dashboard에서의 탐색 어려움
- native notification/menu bar 요구 빈도
- Dashboard process lifecycle 문제
- multi-repo diff 비교 요구
- cmux 없이 상시 관찰해야 하는 시간

요구가 반복되고 Dashboard/client 개선으로 해결되지 않을 때 Tauri 또는 SwiftUI wrapper를 비교한다.
평가 전에는 별도 desktop repo를 만들지 않는다.

## 작업 단위와 commit 전략

권장 예:

```text
test(setup): add cross-repo contract fixtures
fix(setup): fail on partial child setup errors
feat(binbox): expose project list as json
feat(workbench): add project registry
feat(workbench): add tmux backend
feat(nvim): consume workbench project api
feat(cmux): generate workbench actions
feat(workbench): add local dashboard
```

하나의 commit에서 여러 repo의 unrelated cleanup을 섞지 않는다. cross-repo contract 변경은 producer
commit, consumer commit, aggregate lock/doctor update를 같은 작업 묶음으로 추적한다.
