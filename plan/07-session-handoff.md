# 세션·장비 인수인계

## 목적

이전 대화, 로컬 scratch file, AI memory가 없어도 구현을 재개하는 절차다. 이 문서의 command는 repo가
`~/home/setup`에 설치됐다는 현재 기본 경로를 사용한다. 다른 path라면 repo root에서 동일하게 실행한다.

## 새 장비에서 시작

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup
./bootstrap.sh
exec "$SHELL" -l
./doctor.sh
```

무거운 Neovim/tool install이 필요한 새 장비:

```bash
cd ~/home/setup/nvim
./scripts/setup.sh --install --link --with-font --with-tmux-plugins --yes
cd ~/home/setup
./doctor.sh
```

## Windows 장비에서 시작

전체 기능 기본 경로는 Windows Terminal + WSL2다.

PowerShell에서 WSL 설치/상태를 확인한다.

```powershell
wsl --status
wsl --list --verbose
```

Windows Terminal의 WSL profile을 열고 Linux shell에서 실행한다.

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup
./bootstrap.sh
exec "$SHELL" -l
./doctor.sh
```

`windows-wsl.repos`가 macOS 전용 `cmux-config`를 disabled/skipped 처리하므로 대상을 수동 제한하지
않는다. `./bootstrap.sh --show-selection`과 다른 진입점의 결과가 동일해야 하며, cmux 부재만으로
`doctor.sh`가 실패하지 않아야 한다.

현재 계획 단계에서는 native PowerShell에서 `bootstrap.sh`를 실행하지 않는다. native `wb.exe`가 구현된
이후에는 project/worktree/doctor/dashboard와 Windows Terminal backend를 직접 사용할 수 있지만,
binbox/LazyVim 전체 기능은 WSL을 기준으로 한다.

## 기존 장비에서 재개

```bash
cd ~/home/setup
git status --short
git pull --ff-only
./doctor.sh
```

child repo 상태:

```bash
git -C binbox status --short
git -C nvim status --short
git -C cmux-config status --short
```

dirty repo가 있으면 변경 주체와 목적을 먼저 확인한다. 다른 session/사용자의 변경을 자동으로 stash,
reset, checkout하지 않는다.

## 읽기 순서

```text
plan/README.md
→ plan/00-context-and-current-state.md
→ plan/01-decisions-and-target-architecture.md
→ 현재 진행 Phase 문서
→ plan/05-repository-change-map.md
→ plan/06-validation-security-operations.md
```

## 현재 다음 작업 찾기

`plan/README.md`의 진행 상태와 `04-implementation-roadmap.md`를 확인한다. 현재 baseline에서는 Phase 1
macOS/Linux CI 완료 판정이 다음 작업이다. 이후 commit에서 상태가 변경됐다면 최신 문서를 따른다.

확인 command:

```bash
git log --oneline --decorate -10
rg -n "현재 진행 상태|Phase [0-9]|미착수|진행 중|완료" plan
```

## 작업 착수 전 체크

1. 작업할 repo와 모든 consumer를 식별했는가.
2. 현재 branch와 remote가 예상과 같은가.
3. worktree가 clean하거나 기존 변경의 소유권을 확인했는가.
4. `tests/contract-test.sh`, aggregate doctor, `bb list`, nvim link가 통과하는가. WSL에서 cmux가
   disabled/skipped이며 required failure를 만들지 않는가.
5. producer contract를 먼저 고정했는가.
6. compatibility/rollback path가 있는가.
7. 변경 후 증명할 command를 정했는가.
8. Windows 작업이면 native Windows와 WSL 중 실행 위치가 명시됐는가.

## AI Agent에게 전달할 시작 문안

아래 문안을 새 Codex/Claude session에 그대로 전달할 수 있다.

```text
dev-env-setup 저장소의 plan/README.md부터 plan/07-session-handoff.md까지 읽어라.
기본 설치 경로는 ~/home/setup이지만 현재 checkout 경로가 다르면 repo root를 기준으로 하라.
이전 대화나 memory는 없다고 가정하라.

현재 repo와 child repo(binbox, nvim/lazyvim-config, cmux-config)의 git status,
현재 commit, plan 문서에 기록된 baseline 이후 contract 변경을 먼저 확인하라.
Windows 장비라면 native Windows인지 WSL인지 먼저 기록하고, cmux를 required dependency로 가정하지 마라.

plan/04-implementation-roadmap.md에서 가장 앞의 미완료 Phase를 찾고,
그 Phase의 사전 조건·수용 기준·rollback을 유지한 최소 변경 계획을 제시하라.
사용자의 명시적 구현 요청이 없다면 소스를 변경하지 말고 현황과 다음 작업만 보고하라.
구현 요청이 있으면 targeted test부터 추가하고 변경·검증을 완료하라.
```

## 특정 Phase 구현 문안

```text
dev-env-setup/plan 전체를 읽고 Phase <N>의 <slice>를 구현하라.
현재 구현이 계획과 다르면 repository evidence를 사실로 기록하고,
계획 변경이 필요한지 명시적으로 판단하라.

범위 밖 cleanup이나 dependency 추가는 하지 말라.
producer/consumer contract, compatibility fallback, rollback을 보존하라.
변경 후 plan/06-validation-security-operations.md의 관련 검증을 실행하고,
수행한 test output, 변경 파일, 남은 risk를 보고하라.
```

## 세션 종료 시 남길 기록

구현 session은 종료 전에 다음을 plan 문서 또는 commit/PR description에 기록한다.

- 완료한 Phase/slice
- 변경 repo와 commit
- 변경한 contract/schema
- 실행한 test와 결과
- migration/rollback 상태
- 남은 blocker와 다음 단일 작업
- plan 문서와 실제 구현의 차이

권장 handoff 형식:

```text
Status: Phase 0 / contract fixtures 완료
Commits: <repo>: <sha>
Verified: <commands and results>
Compatibility: legacy sessionizer parser 유지
Next: cmux action → command reference checker
Risks: cmux CLI unavailable in Linux CI; JSON-only check 적용
```

## 중단·에스컬레이션 조건

다음은 사용자 또는 owner 결정 없이 추정해 진행하지 않는다.

- 기존 dirty change를 삭제·reset해야 함
- remote main에 force push/history rewrite 필요
- secret/token/credential 필요
- destructive worktree/branch/session 제거
- 외부 network listen 또는 cloud sync 범위 추가
- 기존 Terraform/AWS/Kubernetes safety guard 약화
- 계획 기본안을 바꾸는 새로운 desktop/daemon architecture 도입

그 외 local, reversible, read/test/edit 작업은 현재 Phase 범위에서 계속 진행한다.

## 완료 판정

다른 장비에서 다음이 가능하면 인수인계 목표를 충족한다.

1. 이 repo clone과 `plan/README.md`만으로 목표 구조를 설명할 수 있음
2. 현재 다음 Phase와 파일 surface를 찾을 수 있음
3. acceptance/rollback 없이 임의 설계 결정을 추가하지 않고 착수 가능
4. 기존 workflow와 새 Workbench 경계를 구분할 수 있음
5. 검증과 handoff 기록을 같은 형식으로 남길 수 있음
