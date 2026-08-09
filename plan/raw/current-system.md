# 현재 시스템

## 제품으로 보이는 전체 구조

현재 setup은 단순 dotfiles 설치기보다 다섯 저장소로 구성된 개인 개발환경 운영 시스템에 가깝다.

| 레이어 | 현재 책임 | 대표 진입점 |
|---|---|---|
| dev-env-setup | 저장소 선택, clone/pull, link/setup, 통합 doctor와 contract | `bootstrap.sh`, `upgrade.sh`, `doctor.sh` |
| binbox | Git·tmux·AWS·Kubernetes·Terraform·보안 작업용 shell toolbox | `bb` |
| nvim | LazyVim 편집 환경, tmux 설정, Workbench thin client | `nvim`, tmux keybinding |
| workbench | project·environment·secret·session·worktree·Task 상태와 backend 실행 | `wb`, loopback Dashboard |
| cmux-config | macOS에서 명령과 Workbench를 여는 선택적 client/config | cmux commands/actions |

## 현재 사용자 작업 흐름

1. 새 장비 또는 복구 시 root `bootstrap.sh`가 platform profile에 따라 저장소를 준비한다.
2. 평소 업데이트는 root `upgrade.sh`가 각 저장소의 `sync_cmd`를 순서대로 실행한다.
3. 터미널 작업은 tmux와 LazyVim, `bb`가 독립적으로 수행할 수 있다.
4. Workbench는 프로젝트와 상태를 정규화하고 backend를 골라 project/session/Agent에 진입한다.
5. Dashboard는 같은 로컬 state를 읽고 제한된 typed action만 제공한다.
6. root `doctor.sh`와 contract test가 child 간 이름·링크·기본 동작을 검증한다.

## Workbench 기능 표면

현재 코드와 README에서 확인되는 주요 도메인은 다음과 같다.

- Projects: 등록, 조회, 환경 연결, backend-aware open
- Environments: metadata, expiry, export, 기존 `wenv` migration
- Local Secrets: age 기반 저장소, metadata-only Dashboard, binbox `sec` migration
- tmux Sessions: list/show/attach/jump, managed ownership, adopt/stop
- Worktrees: 안전한 create/list/remove와 외부 worktree read-only 표시
- Agents/Tasks: Codex·Claude managed task와 tmux foreground observed task
- Workflows: 고정 allowlist의 test/security/Terraform plan
- Overview/Doctor/Compatibility: 상태 집계와 fallback 사용 관찰
- Dashboard/Server/Scheduler/Activity: loopback UI, background server, expiry·activity scan
- Backends: shell, tmux, cmux, Windows Terminal/WSL
- Failure diagnostics: backend command, exit code, stdout, stderr 보존

## binbox 기능 표면

현재 `bb list`는 16개 명령을 노출한다.

`agents`, `assm`, `assume`, `binbox-check`, `binbox-doctor`, `binbox-setup`,
`dx`, `gx`, `kx`, `md2jira`, `portcheck`, `sec`, `tfx`, `tm`, `tvx`, `wenv`.

Workbench와 이름이나 기능이 겹치는 `agents`, `tm`, `sec`, `wenv`는 현재도 독립 terminal
fallback과 migration source 역할을 한다. 제거 결정은 내려지지 않았다.

## 데이터와 소유권

| 데이터/행동 | 현재 owner | 주의 |
|---|---|---|
| 관리 저장소 목록·설치 순서·platform severity | root setup | child 구현을 직접 소유하지 않음 |
| tmux session/window/pane lifecycle | tmux | Workbench는 검증한 managed 대상만 변경 |
| project/environment/worktree/Agent registry | Workbench | 로컬 schema-v1 파일과 backup 사용 |
| 직접 실행한 terminal process | 사용자·tmux | Workbench observed task는 stop하지 않음 |
| Git worktree 실체 | Git porcelain | Workbench registry만으로 삭제 판단하지 않음 |
| AWS/Kubernetes/Terraform 실제 operator workflow | binbox 또는 project tool | Workbench workflow는 allowlist만 실행 |
| Secret plaintext | 로컬 age store와 사용자 입력 경계 | Dashboard/history에 평문을 반환하지 않음 |
| cmux live config | cmux-config installer/capture 흐름 | root가 직접 수정하지 않음 |

## 유지되는 안전 경계

- child repo는 독립 repository로 유지된다.
- root pull은 fast-forward only이며 추적 변경이 있으면 해당 repo를 건너뛴다.
- Dashboard는 loopback, per-process token, origin/body limit를 사용한다.
- process는 shell 문자열 대신 executable과 argument array로 실행한다.
- 강제 worktree 삭제, 임의 Dashboard shell, Workbench의 observed process stop은 제공하지 않는다.
- Workbench가 없어도 tmux·LazyVim·binbox의 기본 terminal 경로가 동작하도록 설계되어 있다.

마지막 문장은 설계 의도다. root profile에서 Workbench가 required인 현재 배포 정책과는 별도로
기획에서 다시 확인해야 한다.
