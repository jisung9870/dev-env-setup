# Unified Workbench · tmux-first 운영 콘솔 기획

- 상태: **아카이브 — 후속 구현이 main에 통합됨**
- 작성일: 2026-08-05 · 최종 갱신일: 2026-08-06
- 대상: `workbench`, `binbox`, Workbench Dashboard
- 현재 기준: [새 제품 기획](../PRODUCT-PLAN.md)

## 1. 문제와 결정

사용자가 기대하는 기본 흐름은 다음과 같다.

1. 프로젝트를 선택한다.
2. 프로젝트와 정확히 대응하는 tmux 세션으로 들어간다.
3. 터미널, 셸, Neovim, Agent가 같은 세션 안에서 동작한다.
4. 터미널 창이나 Dashboard를 닫아도 세션과 작업은 유지된다.

현재 CLI의 `wb open --backend tmux`는 이 흐름을 지원한다. tmux 내부에서는 프로젝트 세션을 만든 뒤 현재 클라이언트를 전환하고, 외부에서는 `tmux new-session -A`로 연결한다.

반면 Dashboard의 Open 경로는 의도적으로 tmux를 제외하고 `cmux` 또는 Windows Terminal만 선택한다. WSL에서는 Windows Terminal이 자동 선택되지만 새 탭에서 프로젝트 디렉터리만 열 뿐 tmux 세션에 연결하지 않는다. 지금 겪는 현상은 설정 오류가 아니라 현재 구현 계약의 한계다.

결정:

- 공개 진입점은 `wb` 하나로 통합한다.
- `bb`는 당분간 호환 명령과 Bash 기능 provider로 유지한다.
- 프로젝트 작업 상태는 **session backend**가 담당한다.
- 사용자가 보는 터미널 창은 **surface backend**가 담당한다.
- Dashboard는 세션·Agent·Job·운영 기능을 typed action으로 관리한다.
- 저장소 통합은 실행 계약과 데이터 모델이 안정된 뒤 진행한다.

## 2. 목표 구조

```text
CLI / Dashboard / API
          |
          v
     Workbench Core
       /    |     \
      v     v      v
 Session  Surface  Providers
  tmux    current   binbox
  direct  WT/cmux   k8s/aws/tf
          terminal  agents/jobs
```

| 계층 | 책임 | 예시 |
|---|---|---|
| Session | 지속되는 프로젝트 작업 공간 | tmux 세션, direct process |
| Surface | 세션을 보여 주는 창 | 현재 TTY, Windows Terminal, cmux, Linux terminal, none |
| Provider | 프로젝트 안에서 실행할 기능 | shell env, Kubernetes, Terraform, AWS, Agent |

핵심은 `tmux`와 Windows Terminal을 경쟁 backend로 취급하지 않는 것이다. WSL의 일반적인 조합은 **tmux session + Windows Terminal surface**다.

## 3. tmux 세션 계약

프로젝트 세션 이름은 프로젝트 ID와 정확히 일치시킨다. Workbench가 만든 세션에는 다음 metadata를 기록한다.

```text
@workbench_managed=1
@workbench_project_id=<project-id>
@workbench_project_path=<absolute-path>
```

- 동일 이름의 unmanaged 세션은 자동으로 덮어쓰거나 종료하지 않는다.
- 기존 세션을 관리 대상으로 바꾸려면 명시적인 `adopt`가 필요하다.
- `stop` 직전에도 이름, metadata, 프로젝트 경로를 재검증한다.
- 첫 창 이름은 `main`, Agent 창은 `task-<task-id>`로 한다.
- 셸, Neovim, Agent는 같은 프로젝트 세션 안에서 실행한다.
- 이미 tmux 안인 프로세스에서 중첩 tmux를 만들지 않는다.

### Open 동작표

| 호출 위치 | 기대 동작 |
|---|---|
| CLI, 현재 tmux 내부 | 호출한 현재 tmux client를 프로젝트 세션으로 전환 |
| CLI, tmux 외부 TTY | 현재 TTY에서 프로젝트 세션 생성 또는 attach |
| Dashboard, WSL | 세션 보장 후 Windows Terminal 탭에서 attach |
| Dashboard, macOS + cmux | cmux terminal surface에서 attach |
| Dashboard, Linux desktop | 설정된 terminal surface에서 attach |
| Dashboard, SSH/headless | detached 세션 생성 후 attach 명령 반환 |

백그라운드 Dashboard 서버가 상속한 `TMUX` 값만으로 임의의 사용자 client를 전환하면 안 된다. client 전환은 호출 주체가 명확하거나 명시적인 client binding이 있을 때만 수행한다.

WSL에서는 개념적으로 다음 argument 배열을 실행한다.

```text
wt.exe --window <target> new-tab|split-pane --profile <profile>
  wsl.exe -d <distro> --cd <project-path> --exec
  tmux new-session -A -s <project-id> -c <project-path>
```

쉘 문자열을 이어 붙이지 않고 각 argument를 분리해 전달한다.

## 4. 통합 CLI

```text
wb open alpha
wb sessions list
wb sessions show alpha
wb sessions jump alpha
wb sessions stop alpha
wb agents
wb jobs
wb k8s ...
wb terraform ...
wb aws ...
```

Open은 session과 surface를 별도로 노출한다.

```text
wb open alpha --session tmux --surface auto
wb open alpha --session tmux --surface windows-terminal
wb open alpha --session tmux --surface current
wb open alpha --session tmux --surface none
```

기존 옵션은 호환 계층에서 해석한다.

| 기존 옵션 | 새 의미 |
|---|---|
| `--backend tmux` | `--session tmux --surface auto` |
| `--backend windows-terminal` | `--session direct --surface windows-terminal` |
| `--backend cmux` | `--session direct --surface cmux` |
| `--backend shell` | `--session direct --surface current` |

프로필 schema v2의 핵심 필드:

```toml
session_backend = "tmux"
surface_backend = "auto"
dashboard_surface = "auto"
reuse_current_tmux = true
```

v1 reader는 유지하고 내부에서 v2 모델로 변환한다. binbox 기능은 `wb` provider로도 노출하되 기존 `bb`는 안정적인 독립 진입점으로 계속 같은 typed request를 호출한다. fzf 기반 흐름은 CLI 전용 UX로 유지한다.

## 5. Dashboard 확장

화면 구조:

- Overview
- Projects
- Sessions
- Agents & Jobs
- Kubernetes
- Terraform
- AWS
- Doctor

프로젝트 상세에는 tmux 세션의 소유권·client·window, Agent와 Job, worktree와 Git 상태를 표시한다. 버튼은 단순한 Open 하나가 아니라 `Open tmux`, `New terminal`, `Switch terminal`, `Create detached`처럼 실제 결과를 드러낸다.

| 단계 | 기능 |
|---|---|
| Read-only | 세션, Agent, Job, Git, Kubernetes 리소스, Terraform 상태, AWS identity |
| Managed job | 로그 tail, port-forward, Terraform plan, 테스트 |
| Controlled write | 허용된 deploy/restart/scale 등 사전 정의 action |
| High risk | Terraform apply/destroy/state, Kubernetes delete/exec 등 별도 승인 |

Dashboard는 임의 명령어, 임의 경로, 임의 prompt를 서버 셸에 전달하는 범용 원격 터미널이 되어서는 안 된다. action은 allowlist, timeout, 출력 제한, secret redaction을 적용한 구조화된 요청이어야 한다.

브라우저의 환경 변경은 백그라운드 서버 process 전체에 주입하지 않는다. context는 프로젝트, Job 또는 새 terminal window 단위로 적용하며 credential을 브라우저 상태나 로그에 남기지 않는다.

## 6. 데이터 모델

Session 상태 예시:

```json
{
  "project_id": "alpha",
  "backend": "tmux",
  "session_name": "alpha",
  "managed": true,
  "attached_clients": 1,
  "windows": ["main", "task-123"],
  "project_path": "/workspace/alpha"
}
```

Job 상태 예시:

```json
{
  "id": "job-123",
  "project_id": "alpha",
  "kind": "terraform-plan",
  "status": "running",
  "started_at": "2026-08-05T12:00:00+09:00",
  "log_ref": "logs/job-123"
}
```

기존 `agents.json`은 즉시 합치지 않는다. 먼저 Session과 Job API가 기존 Agent store를 읽는 adapter를 제공하고 migration과 rollback 검증 뒤 저장 형식을 통합한다.

## 7. 저장소 통합 목표

```text
workbench/
  cmd/wb
  internal/...
  providers/binbox/...
  tests/contracts/...
```

- Git history를 보존해 binbox 코드를 가져온다.
- 같은 release가 `wb`와 `bb` 진입점을 함께 설치할 수 있으며 binbox 이름과 기능군은 계속 유지한다.
- Windows native에는 `wb`, WSL에는 `wb`와 `bb` 호환 계층을 설치할 수 있다.
- binbox 원격 저장소는 독립 저장소 또는 mirror로 계속 운영할 수 있다. 코드 저장소 통합은 archive나 제거를 전제로 하지 않는다.
- 물리적 저장소보다 명령 계약, 테스트, release 경계를 먼저 통합한다.

## 8. 구현 순서

### Slice 0 — Dashboard tmux 회귀 수정

1. Open 요청에 `cli-interactive`와 `dashboard` origin을 구분한다.
2. WSL에 tmux session + Windows Terminal surface 조합을 추가한다.
3. Dashboard auto가 tmux 기본 설정을 session 선호로 존중하게 한다.
4. 명시적 tmux 요청을 허용하되 서버 process에서 직접 attach하지 않는다.
5. 결과에 선택된 session과 surface를 모두 반환한다.

수용 기준:

- 프로젝트 `alpha`에는 정확히 하나의 관리 세션 `alpha`가 생긴다.
- Dashboard로 열린 Windows Terminal은 해당 세션에 연결된다.
- 다시 열면 같은 세션을 재사용하고 탭을 닫아도 세션은 유지된다.
- Agent 창도 같은 세션에 생성된다.
- 서버가 `TMUX`를 상속해도 임의 client를 전환하지 않는다.
구현 상태(2026-08-05):

- typed `OpenRequest.Session`과 session/surface 결과 계약 구현
- WSL `auto` 및 명시적 tmux 요청을 Windows Terminal surface로 연결
- `wt.exe -> wsl.exe --exec tmux new-session -A` argument-array 회귀 테스트 추가
- 전체 race/vet와 6개 OS/architecture cross-build 통과
- 물리 WSL smoke 통과: Dashboard API attach, 재Open 시 단일 세션·복수 client, detach 후 세션 유지, Codex pane 동일 세션 생성·중지 확인
- ownership metadata와 unmanaged session `adopt`까지 Slice 1의 첫 묶음에서 구현



### Slice 1 — Session/Surface core

- backend 모델을 Session과 Surface로 분리한다.
- 세션 registry와 ownership metadata를 구현한다.
- `wb sessions list|show|jump|stop|adopt`를 추가한다.
- profile schema v2와 v1 migration reader를 추가한다.
- CLI와 Dashboard가 같은 Open request/result를 사용한다.

구현 상태(2026-08-06, 1차):

- live tmux 상태를 읽는 공용 session manager와 managed/legacy/foreign 분류 구현
- project ID/path metadata 기록, legacy 자동 인수 금지, 명시적 path-verified `adopt` 구현
- `wb sessions list|show|jump|stop|adopt`와 JSON/exit-code 계약 구현
- tmux adapter, Dashboard Open, Agent tmux runtime을 같은 manager에 연결
- 실제 tmux smoke에서 legacy stop 거부, adopt, managed stop 및 기존 세션 비간섭 확인
- 계층형 `wb --help`/subcommand help와 `wb completion zsh`, idempotent `.zshrc` 설치 계약 구현
- profile schema v2/v1 migration reader와 Dashboard Sessions 화면은 다음 묶음으로 유지

### Slice 2 — 통합 CLI facade

- `wb k8s`, `wb terraform`, `wb aws`, `wb env`를 추가한다.
- binbox 기능을 typed provider로 연결한다.
- `bb`와 `wb` 명령 mapping·호환 테스트를 기록한다. 사용량 관찰은 제거 조건으로 사용하지 않는다.
- allowlist, timeout, 출력 제한, secret redaction을 공통 적용한다.

### Slice 3 — Dashboard Sessions/Jobs

- Sessions와 Agents & Jobs 화면을 추가한다.
- Kubernetes, Terraform, AWS는 read-only panel부터 제공한다.
- background job의 상태, 취소, 로그 API를 추가한다.

### Slice 4 — Monorepo

- binbox history를 Workbench로 가져온다.
- release, installer, 문서, 테스트 pipeline을 합친다.
- 기존 저장소와 설치 경로 rollback을 검증한다.

### Slice 5 — Controlled operations

낮은 위험의 사전 정의 write action부터 추가하고, 고위험 작업은 preview, 명시적 승인, audit log를 갖춘 뒤 활성화한다.

## 9. 테스트 전략

- CLI와 Dashboard의 session/surface 결정 계약 테스트
- managed/unmanaged 충돌, adopt, 재사용, stop 재검증
- WSL + Windows Terminal argument 배열과 실제 attach smoke
- Linux terminal, macOS cmux, SSH/headless matrix
- native Windows fallback
- command/path injection, secret redaction, timeout, 출력 상한
- 기존 `wb open --backend tmux`, `bb tm`, LazyVim 회귀

## 10. Rollback 원칙

- 기존 `wb open --backend tmux`, `bb tm`, LazyVim 경로를 유지한다.
- profile v1 reader를 제거하지 않는다.
- 저장소 통합 전 양쪽 repo의 기준 SHA를 고정한다.
- 새 installer에서 이전 release로 되돌리는 절차를 제공한다.
- 실제 workflow와 물리적 WSL smoke 전에는 기본값과 fallback을 제거하지 않는다.

## 11. 첫 구현 범위

첫 PR은 Dashboard에서 tmux 프로젝트를 올바르게 여는 문제만 해결한다.

- `workbench/internal/backend`: session/surface 선택 경계
- `workbench/internal/sessions`: 세션 보장과 ownership 검사
- `workbench/adapters/tmux`: detached ensure와 attach command 생성 분리
- `workbench/adapters/windows_terminal`: WSL tmux attach argument
- `workbench/internal/cli/dashboard.go`: Dashboard Open orchestration
- 관련 unit, integration, WSL smoke test와 문서

Monorepo와 provider 확장은 첫 PR에 포함하지 않는다.
