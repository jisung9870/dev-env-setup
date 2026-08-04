# Workbench CLI와 데이터 계약

## 목표

`wb`는 UI가 없어도 사용할 수 있는 headless control plane이다. cmux, tmux, LazyVim, Dashboard는
이 문서의 command와 JSON contract를 통해서만 project/session/Agent/worktree 상태를 다룬다.

초기 구현 언어는 **Go**로 고정한다. 구현 착수 기준 toolchain의 `lazyvim-config/.tool-versions`가
`golang 1.25.12`를 사용하므로 첫 baseline도 Go 1.25.12로 맞춘다. 같은 source에서 macOS, Linux,
Windows binary를 build한다.

선택 근거:

- macOS, Linux/WSL, Windows single binary 배포
- JSON, process, file, local HTTP server를 standard library 중심으로 구현 가능
- Agent/session 상태처럼 Bash보다 복잡한 구조화 로직에 적합
- 기존 binbox는 Bash provider로 남겨 빠른 script 수정성을 보존

구현은 다음 조건을 만족해야 한다.

- macOS, Linux/WSL, Windows에서 single binary 또는 의존성이 명확한 실행 형태
- JSON encode/decode와 atomic file write 지원
- shell interpolation 없이 argument 배열로 외부 command 실행
- provider별 timeout, exit code, stdout/stderr 보존

CLI framework/plugin framework부터 도입하지 않는다. command parsing, JSON, process execution, local HTTP
server는 우선 standard library로 구현하고, TOML parser처럼 standard library에 없는 기능만 작은
dependency로 추가한다. dependency 선택과 version은 Phase 2 첫 commit에서 근거와 함께 lock한다.

## 명령 구조

```text
wb
├─ projects list|show|add|remove
├─ open
├─ sessions list|show|open|close
├─ worktrees list|create|remove
├─ agents list|show|start|stop|jump
├─ dashboard
├─ doctor
├─ config show|validate
└─ migrate
```

### Project

```bash
wb projects list [--json]
wb projects show <project-id> [--json]
wb projects add <path> [--id <id>] [--profile <profile>]
wb projects remove <project-id>
wb open <project-id> [--backend auto|cmux|windows-terminal|tmux|shell]
```

규칙:

- `project_id`는 장비가 바뀌어도 유지되는 사람이 읽을 수 있는 stable ID다.
- path는 profile 또는 machine overlay로 바꿀 수 있다.
- 같은 canonical path를 두 project가 소유하지 않는다.
- remove는 project registry만 변경하며 repo/worktree를 삭제하지 않는다.

### Session

```bash
wb sessions list [--json]
wb sessions open <project-id> [--backend <backend>]
wb sessions close <session-id>
```

session은 backend instance를 가리킨다. tmux session, cmux workspace, plain shell process를 같은 필드로
억지로 표현하지 않고 공통 identity와 backend-specific reference를 분리한다.

### Worktree

```bash
wb worktrees list <project-id> [--json]
wb worktrees create <project-id> <branch> [--base <ref>]
wb worktrees remove <worktree-id> [--delete-branch]
```

안전 규칙:

- 같은 repo에서 같은 branch의 worktree를 중복 생성하지 않는다.
- dirty worktree는 기본 remove를 거부한다.
- branch 삭제는 별도 `--delete-branch`와 확인 절차를 요구한다.
- 실제 path를 삭제하기 전에 `git worktree list --porcelain`과 일치하는지 확인한다.

### Agent

```bash
wb agents list [--project <id>] [--json]
wb agents show <task-id> [--json]
wb agents start <project-id> --agent codex|claude [--worktree <id>] [--backend <backend>]
wb agents jump <task-id>
wb agents stop <task-id>
```

`agents stop`은 process/session에 영향을 주므로 대상, backend reference, 실행 중 상태를 다시 확인한다.
등록되지 않은 process를 task ID 추측으로 종료하지 않는다.

### Dashboard와 doctor

```bash
wb dashboard [--open auto|cmux|browser|none] [--port 0]
wb doctor [--profile <name>] [--json] [--strict]
wb config validate
```

- `--port 0`은 OS가 사용 가능한 port를 선택하게 한다.
- 기본 listen address는 `127.0.0.1`과 `::1` 범위로 제한한다.
- `--strict`는 optional capability warning도 실패로 취급할 때만 사용한다.

### Windows와 WSL

```bash
# PowerShell/Command Prompt
wb.exe open terraform-lab --backend windows-terminal

# WSL에서 Windows Terminal에 새 WSL tab 열기
wb open terraform-lab --backend windows-terminal

# Windows Terminal 안 WSL에서 tmux 사용
wb open terraform-lab --backend tmux
```

Windows Terminal adapter는 `wt.exe`의 profile/starting-directory/tab/pane command를 argument 배열로
생성한다. WSL에서 execution alias `wt`를 직접 가정하지 않고 Windows interop을 통해 `wt.exe`를
호출할 수 있는지 `detect()`에서 확인한다.

## JSON envelope

모든 `--json` command는 최소한 다음 envelope를 사용한다.

```json
{
  "schema_version": 1,
  "ok": true,
  "data": {},
  "warnings": [],
  "error": null
}
```

실패 예:

```json
{
  "schema_version": 1,
  "ok": false,
  "data": null,
  "warnings": [],
  "error": {
    "code": "BACKEND_UNAVAILABLE",
    "message": "cmux backend is unavailable",
    "details": {
      "backend": "cmux",
      "fallbacks": ["tmux", "shell"]
    }
  }
}
```

규칙:

- JSON mode에서 stdout에는 JSON 한 개만 출력한다.
- diagnostic/progress는 stderr에 출력한다.
- `schema_version` major가 다르면 client는 해석을 중단하고 upgrade guidance를 표시한다.
- 새 optional field 추가는 같은 version에서 허용하되 client는 unknown field를 무시한다.
- 기존 field 의미 변경과 삭제는 version을 올린다.

## Exit code

| code | 의미 |
|---:|---|
| 0 | 요청 성공 |
| 1 | 일반 실행 실패 또는 provider 실패 |
| 2 | argument/config/schema 오류 |
| 3 | capability/backend unavailable |
| 4 | conflict 또는 unsafe state로 작업 거부 |
| 5 | partial result; 요청 결과 일부만 수집 |

`doctor`와 `list` 계열은 일부 provider를 읽지 못해도 수집 가능한 data를 반환할 수 있다. 이 경우
`ok=false`, exit `5`, `warnings`와 `error.details`에 누락 provider를 표시한다.

## Phase 1 binbox compatibility API

Workbench core 이전의 producer/consumer 계약은 다음 네 명령으로 고정한다.

```bash
bb tm projects --json
bb tm sessions --json
bb agents --json
bb doctor --json
```

네 명령 모두 위 schema v1 envelope를 사용한다. `projects`, `sessions`, `agents`, `capabilities` 배열은
각각 `data` 아래에 위치한다. `agents`의 legacy pane 관찰 결과는 stable Workbench task로 오해하지 않도록
`id=legacy:<pane-id>`와 `state_source=scrape`를 포함한다. tmux/Python encoder가 없으면 exit `3`과
`CAPABILITY_UNAVAILABLE`, JSON mode의 잘못된 argument는 exit `2`와 `INVALID_ARGUMENT`을 반환한다.

LazyVim client는 `projects` 배열의 `path`만 소비하며 5초 timeout, JSON parse 실패, non-zero exit,
schema mismatch를 설명한 뒤 기존 sessionizer parser로 fallback한다. schema version이 다르면 부분
해석하지 않고 binbox와 LazyVim의 동시 update를 안내한다.

## 핵심 데이터 모델

### Project

```json
{
  "id": "terraform-lab",
  "name": "Terraform Lab",
  "path": "/Users/me/home/lab/terraform-lab",
  "repo_root": "/Users/me/home/lab/terraform-lab",
  "default_backend": "auto",
  "editor": "nvim",
  "tags": ["terraform", "personal"],
  "profile": "personal"
}
```

### Session

```json
{
  "id": "session-01JXYZ",
  "project_id": "terraform-lab",
  "backend": "tmux",
  "backend_ref": "terraform-lab",
  "state": "active",
  "started_at": "2026-08-04T16:40:00+09:00"
}
```

### Agent task

```json
{
  "id": "task-01JXYZ",
  "project_id": "terraform-lab",
  "worktree_id": "wt-rds-monitoring",
  "agent_kind": "codex",
  "backend": "cmux",
  "backend_ref": "surface:12",
  "state": "running",
  "request_summary": "Implement CloudWatch module",
  "started_at": "2026-08-04T16:42:00+09:00",
  "last_event_at": "2026-08-04T16:45:00+09:00"
}
```

허용 state의 초기 집합:

```text
starting → running → waiting|idle → completed
                    └────────────→ failed|stopped
```

UI 문자열을 state 판정의 source로 사용하지 않는다. legacy pane만 `state_source=scrape`로 표시한다.

## 설정과 state 경로

```text
${XDG_CONFIG_HOME:-~/.config}/workbench/
├─ config.toml
├─ projects.toml
├─ profiles/
│  ├─ personal.toml
│  └─ work.toml
└─ workflows/

${XDG_STATE_HOME:-~/.local/state}/workbench/
├─ sessions.json
├─ agents.json
├─ worktrees.json
├─ events.jsonl
└─ backups/
```

Windows native path는 Go의 사용자 config/cache directory API를 사용해 다음 logical location에 둔다.

```text
%APPDATA%\workbench\          config, projects, profiles
%LOCALAPPDATA%\workbench\    state, events, backups
```

Windows native와 WSL은 state file을 직접 공유하지 않는다. 같은 project identity가 필요하면 명시적
import/export 또는 future sync contract를 사용한다. `/mnt/c`와 Windows path를 자동으로 동일 canonical
path로 간주하지 않는다.

설정과 runtime state를 분리한다. 설정은 Git 관리 가능하지만 state, event, socket, token은 commit하지
않는다.

## Atomic write와 migration

state 변경 순서:

1. 현재 file read와 schema validation
2. timestamp backup 또는 이전 valid snapshot 확인
3. 같은 filesystem에 temporary file write
4. flush와 close
5. atomic rename
6. 다시 read/validate

migration은 `wb migrate --check`와 `wb migrate --apply`를 분리한다. 자동 migration 실패 시 원본을
보존하고 이전 binary/compatibility path를 사용할 수 있어야 한다.

## Backend interface

각 adapter가 제공할 공통 capability:

```text
detect()                backend availability와 version
open_project(project)   workspace/session/shell open
list_sessions()         backend sessions
launch_agent(task)      Agent process 시작과 backend_ref 반환
jump(ref)               해당 surface/pane/process로 이동
stop(ref)               명시적 대상 종료
health()                doctor details
```

모든 backend가 모든 capability를 제공할 필요는 없다. `detect()`가 capability set을 반환하며 UI는
없는 action을 숨기거나 disabled reason을 표시한다.

Windows Terminal adapter의 initial capability:

```text
detect wt.exe and profiles
open project in new/existing window
open native PowerShell or configured WSL profile
set starting directory
create optional tab/pane layout
launch Agent command in selected profile
```

Windows Terminal은 session state owner가 아니므로 tab/pane enumeration이 안정적으로 제공되지 않는 경우
Workbench registry의 launch record와 process health만 사용하고 “완전한 terminal inventory”를 추정하지
않는다.

## Provider 경계

`wb`는 기존 `bb tfx`, `bb kx`, `bb assume` 등을 재구현하지 않는다. workflow command는 stable
command ID에서 provider와 argument schema로 매핑한다.

```toml
[[workflows]]
id = "terraform-plan"
provider = "binbox"
command = ["bb", "tfx", "plan"]
requires = ["terraform", "binbox"]
```

Dashboard가 arbitrary command string을 받아 shell로 넘기지 않게 한다.

### Native Windows에서 WSL provider 호출

초기 release의 native bridge는 암묵적 path 추론을 하지 않는다. project에 다음 machine-local 필드가
모두 있을 때만 WSL provider capability를 활성화한다.

```toml
[projects.terraform-lab.windows_wsl]
distro = "Ubuntu-24.04"
wsl_path = "/home/user/projects/terraform-lab"
```

고정 계약:

- transport는 `wsl.exe -d <distro> --exec wb provider run --project-dir <wsl_path> -- <provider> <args...>`
  형태의 argument array다. WSL의 `wb provider run`이 working directory와 provider allowlist를 적용한다.
- Windows path에서 `wsl_path`를 자동 생성하지 않는다. distro 또는 path가 없으면 unavailable이다.
- provider stdout은 versioned JSON envelope, stderr와 exit code는 그대로 보존한다.
- timeout은 provider별 설정을 따르고 cancel은 host `wsl.exe` process와 등록된 child task에 전달한다.
- bridge를 호출한 native `wb.exe` registry가 task record를 소유하고 distro/path/source를 기록한다.
- Windows Terminal 안 WSL에서 Linux `wb`를 직접 실행한 경우에는 Linux registry가 소유한다.
- 두 registry를 자동 병합하지 않으며 같은 task를 양쪽에 중복 등록하지 않는다.
