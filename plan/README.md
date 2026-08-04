# Personal Workbench 계획 패키지

- 상태: **계획 기준선 확정, 구현 미착수**
- 최종 갱신일: 2026-08-04
- 독자: 현재 대화나 이전 장비의 context가 전혀 없는 사람 또는 AI Agent
- 목표: 이 디렉터리만 읽고 Personal Workbench 구현을 안전하게 이어갈 수 있게 한다.

## 지금 알아야 할 결론

현재 `tmux + LazyVim + cmux + binbox` 환경은 폐기하지 않는다. 다음 구조로 점진 진화한다.

```text
dev-env-setup      장비 provisioning, 호환 repo snapshot, 통합 doctor
       │
       ▼
workbench (`wb`)   프로젝트·세션·Agent·worktree의 source of truth
  ├─ cmux adapter  로컬 desktop workspace
  ├─ wt adapter    Windows Terminal tab/pane과 WSL 진입
  ├─ tmux adapter  장시간 세션·SSH·재접속
  ├─ nvim client   LazyVim picker·상태·작업 실행
  ├─ dashboard     localhost Web UI, cmux browser에서도 사용 가능
  └─ binbox        Kubernetes·Terraform·AWS 등 실제 실행 provider
```

중요한 경계:

- Workbench는 cmux 전용이 아니다.
- cmux, Windows Terminal, tmux, 일반 shell, LazyVim, local Web UI는 모두 같은 `wb` core의
  client/backend다.
- Windows에서는 Windows Terminal + WSL을 전체 기능 기본 경로로 사용한다.
- Windows native에서는 `wb.exe` core와 `wt.exe` backend를 지원하고, Bash 기반 binbox 기능은 WSL
  adapter를 통해 실행하거나 unavailable capability로 명시한다.
- 처음부터 별도 desktop 앱을 만들지 않는다.
- 우선 headless CLI와 versioned JSON contract를 만든다.
- UI는 localhost dashboard로 시작하고, 필요가 입증될 때만 Tauri/SwiftUI 앱으로 포장한다.

## 현재 진행 상태

| 항목 | 상태 | 다음 행동 |
|---|---|---|
| 네 repo 구조·결합 분석 | 완료 | 변경 전 baseline commit 재확인 |
| 목표 아키텍처와 대안 비교 | 완료 | Hybrid Workbench를 기본안으로 사용 |
| CLI/API와 데이터 경계 | 계획 완료 | Phase 0 계약 테스트 후 Phase 1 구현 |
| Desktop/Web UI 방향 | 계획 완료 | core 이후 `wb dashboard` 구현 |
| LazyVim UI 방향 | 계획 완료 | JSON API 이후 thin client 구현 |
| 실제 소스 변경 | 미착수 | [04-implementation-roadmap.md](04-implementation-roadmap.md)의 Phase 0부터 시작 |

## 읽는 순서

새 세션이나 새 장비에서는 다음 순서로 읽는다.

1. [00-context-and-current-state.md](00-context-and-current-state.md) — 왜 이 계획이 생겼고 현재 무엇이 있는가
2. [01-decisions-and-target-architecture.md](01-decisions-and-target-architecture.md) — 대안과 채택한 기본 방향
3. [02-workbench-cli-and-data-contracts.md](02-workbench-cli-and-data-contracts.md) — `wb` 명령, schema, backend 계약
4. [03-ui-and-client-spec.md](03-ui-and-client-spec.md) — Dashboard, cmux, Windows Terminal, LazyVim UI
5. [04-implementation-roadmap.md](04-implementation-roadmap.md) — 구현 순서와 완료/롤백 조건
6. [05-repository-change-map.md](05-repository-change-map.md) — 각 repo에서 바꿀 파일과 책임
7. [06-validation-security-operations.md](06-validation-security-operations.md) — 테스트, 보안, 운영 기준
8. [07-session-handoff.md](07-session-handoff.md) — context 없이 재개하는 명령과 handoff 문안

## Source of truth 규칙

- 이 디렉터리의 계획은 `plan/README.md`에서 연결된 파일을 기준으로 한다.
- 루트 `WORKBENCH-PLAN.md`는 호환용 진입점이며 내용을 중복 보관하지 않는다.
- 구현 중 결정이 바뀌면 관련 문서와 [01-decisions-and-target-architecture.md](01-decisions-and-target-architecture.md)의
  결정 기록을 함께 갱신한다.
- 코드와 문서가 충돌하면 현재 구현을 사실로 기록하되, 계획 변경 여부는 명시적으로 결정한다.
- 완료되지 않은 항목을 완료로 표시하지 않는다.

## 즉시 시작할 작업

현재 다음 작업은 **Phase 0 — 기존 계약 고정**이다.

착수 전:

```bash
cd ~/home/setup
git pull --ff-only
./doctor.sh

git -C binbox status --short
git -C nvim status --short
git -C cmux-config status --short
```

Phase 0 이전 Windows/WSL에서는 cmux가 없는 것이 정상이다. 이때 공통 `doctor.sh`의 성공을 요구하지
않고 다음을 baseline 증거로 남긴다.

```bash
./bootstrap.sh binbox nvim
./binbox/bb list
test -e "$HOME/.config/nvim"
git -C binbox status --short
git -C nvim status --short
./doctor.sh  # cmux repo/link 누락만으로 non-zero인지 출력 확인
```

`bootstrap.sh` 출력에 binbox/nvim setup warning이 없어야 하고, `bb list`와 nvim link 검사가 성공해야
한다. aggregate doctor의 cmux-only failure는 Phase 0에서 platform-aware selector가 들어갈 때 제거한다.

그다음 [04-implementation-roadmap.md](04-implementation-roadmap.md)의 Phase 0 작업을 작은 commit으로
나누어 수행한다. 아직 신규 `workbench` repo부터 만들지 않는다. 먼저 기존 producer/consumer 계약을
테스트로 고정해야 한다.

## 범위 제외

현재 계획에서 의도적으로 제외한다.

- Orca 또는 다른 상용 Agent IDE로 전체 환경 교체
- 외부 네트워크에 노출되는 Workbench server
- 팀/조직용 multi-user 권한 모델
- arbitrary shell command를 Dashboard에서 자유 입력·실행하는 기능
- 처음부터 상시 daemon 또는 cloud synchronization 도입

필요성이 확인되면 별도 결정 기록을 만든 뒤 범위를 확장한다.
