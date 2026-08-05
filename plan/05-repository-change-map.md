# 저장소 변경 지도

## 목적

구현자가 “어느 repo에서 무엇을 바꿔야 하는가”를 다시 조사하지 않도록 목표 책임과 예상 변경
surface를 기록한다. 정확한 파일명은 구현 시 현재 tree를 재검증한다.

## 목표 repository 구성

```text
dev-env-setup/             existing; provisioning and compatibility owner
binbox/                    existing; execution provider
cmux-config/               existing; cmux client/config
lazyvim-config/            existing; editor client/config
workbench/                 existing; headless core and Dashboard
```

`tmux-config`와 `workbench.nvim`을 당장 별도 repo로 만들지 않는다. 독립 release/test 필요가 반복될 때만
분리한다.

## `dev-env-setup`

### 유지

- `bootstrap.sh`: orchestration entrypoint
- `upgrade.sh`: dependency-order sync
- `doctor.sh`: aggregate health
- repo manifest

### 추가 후보

```text
manifests/
├─ repos.toml
└─ schemas/
profiles/
├─ personal.toml
├─ work.toml
└─ minimal.toml
platforms/
├─ macos.repos
├─ linux.repos
└─ windows-wsl.repos
locks/
└─ repos.lock
tests/
├─ fixtures/
├─ contract-test.sh
└─ bootstrap-test.sh
```

### 변경 책임

- compatible repo snapshot
- partial failure semantics
- cross-repo contract fixtures
- profile별 required/optional capability
- platform별 child repo 선택; `cmux-config`는 macOS optional이며 Linux/WSL에서는 skipped
- child installer만 호출하고 runtime link owner 중복 제거
- parent가 유지하는 유일한 repo alias는 `~/binbox`

### 주의

현재 pipe-delimited `repos.txt`와 `eval` command를 한 번에 교체하지 않는다. 새 manifest reader를
read-only check로 먼저 추가하고 결과가 기존 parser와 같은지 검증한 뒤 apply path로 전환한다.
Phase 0에서는 `locks/repos.lock`을 `name full-sha` 형식으로 먼저 추가한다. nvim과 cmux의 parent
`link_target`은 child installer 검증과 backup 이후 비운다.

## `binbox`

### 현재 핵심 surface

```text
bb
libexec/
lib/
shell/
completions/
tmux-layouts/
tests/
```

### 예상 변경

- `libexec/tm`: project/session JSON subcommand
- `libexec/agents`: JSON output, explicit metadata 우선, scraping fallback 표시
- `libexec/binbox-doctor`: structured capability 결과
- shared JSON envelope helper 또는 작은 common formatter
- Bats fixtures for JSON/error/exit code
- completion과 README/help 갱신

### 경계

- `binbox`는 Kubernetes/Terraform/AWS provider를 계속 소유한다.
- Workbench project/task state를 binbox 내부 file로 새로 만들지 않는다.
- UI-specific formatting과 web server를 binbox에 추가하지 않는다.

## `cmux-config`

### 현재 핵심 surface

```text
config.d/base/
config.d/actions/
config.d/commands/
config.d/ui/
scripts/build-config.py
scripts/check-config.sh
cmux.json
```

### 예상 변경

```text
config.d/generated/       wb가 생성하는 project/workflow fragment
scripts/check-references  action → command reference 검사
scripts/generate-wb       wb output을 fragment로 변환 또는 wb command 호출 wrapper
.github/workflows/        drift/schema/sensitive 검사
```

### 경계

- cmux base preference는 사람이 관리한다.
- project registry와 Agent state는 보관하지 않는다.
- generated output을 직접 수정하지 않는다.
- `wb` unavailable 시 기본 terminal/browser와 기존 safe action은 유지한다.

## `lazyvim-config`

### 현재 핵심 surface

```text
lua/config/
lua/plugins/
scripts/config/.tmux.conf
scripts/setup*.sh
scripts/doctor.sh
doc/
```

### 예상 변경

```text
lua/workbench/client.lua      wb async/json client
lua/workbench/projects.lua    Snacks project picker
lua/workbench/agents.lua      Agent/task picker
lua/workbench/worktrees.lua   worktree picker
lua/workbench/doctor.lua      capability/status UI
lua/plugins/workbench.lua     plugin wiring
doc/nvim-workbench.txt        help and troubleshooting
```

기존 `lua/plugins/editor.lua` sessionizer parser는 API fallback으로 이동한 뒤 제거 조건을 만족할 때
삭제한다. `terminal.lua`의 `bb tm` mapping도 `wb open` migration과 compatibility를 함께 설계한다.

### tmux 설정

현재 `.tmux.conf`는 이 repo에 유지한다. 다음이 반복될 때만 분리한다.

- Neovim release와 무관하게 tmux 설정을 독립 배포해야 함
- 여러 editor가 같은 tmux config를 공유
- tmux-specific CI/release가 필요

## 신규 `workbench`

권장 초기 구조:

```text
workbench/
├─ cmd/wb/
├─ internal/
│  ├─ config/
│  ├─ projects/
│  ├─ sessions/
│  ├─ worktrees/
│  ├─ agents/
│  ├─ events/
│  └─ doctor/
├─ adapters/
│  ├─ shell/
│  ├─ tmux/
│  ├─ cmux/
│  ├─ windows_terminal/
│  ├─ wsl/
│  ├─ binbox/
│  ├─ git/
│  ├─ codex/
│  └─ claude/
├─ schemas/
├─ web/
├─ tests/
└─ docs/
```

### Slice별 생성 순서

1. config/schema/errors/JSON envelope
2. project registry
3. shell backend
4. tmux, cmux, Windows Terminal/WSL adapters
5. worktree
6. Agent registry
7. Dashboard

처음부터 plugin system이나 generic RPC framework를 만들지 않는다. adapter interface가 두 개 이상의
실제 구현에서 반복되는 부분을 확인한 뒤 추출한다.

## Cross-repo contract 변경 절차

예: project registry가 sessionizer file에서 `wb projects list --json`으로 바뀔 때.

1. 기존 fixture와 behavior test 추가
2. producer에 새 API 추가
3. consumer가 새 API 우선, legacy fallback 사용
4. aggregate doctor에 API/version/fallback 확인 추가
5. 지원 장비 update와 관찰
6. fallback 미사용 증거 확인
7. legacy parser 제거
8. docs, lock, completion 갱신

producer와 consumer를 같은 날 무조건 latest로 pull해야만 동작하는 상태를 만들지 않는다.

## Windows 관련 repo 경계

### `dev-env-setup`

- 현재 Bash bootstrap은 Windows Terminal 안 WSL에서 실행하는 경로를 Tier 1으로 유지한다.
- WSL에서는 `windows-wsl.repos`가 cmux child setup을 자동 제외한다.
- Phase 0에 Windows Terminal + WSL doctor/profile smoke를 추가한다.
- native PowerShell bootstrap을 Bash와 별도 구현해 즉시 복제하지 않는다.
- `wb.exe` release가 안정화된 뒤 native Windows bootstrap wrapper 필요성을 재검토한다.

### `binbox`와 `lazyvim-config`

- full 기능은 WSL 내부에서 기존 Bash/Linux 방식으로 실행한다.
- native Windows용 PowerShell port를 만들지 않는다.
- native `wb.exe`가 provider를 요청하면 WSL adapter로 실행하거나 unavailable을 반환한다.

### `workbench`

- Windows build와 `wt.exe` adapter를 core repo에서 함께 관리한다.
- Windows/WSL path 변환은 별도 adapter boundary에 두고 project core에 암묵적으로 섞지 않는다.
- Windows native와 WSL state는 초기에는 별도 유지한다.
