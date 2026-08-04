# 결정과 목표 아키텍처

## 결과 상태

**기본안: Hybrid Workbench를 조건부 채택한다.** 조건은 Phase 0에서 기존 계약을 테스트로 고정하고,
기존 `bb tm`·cmux command·LazyVim picker를 migration 기간 동안 rollback 경로로 유지하는 것이다.

## 결정 기준

1. tmux와 LazyVim 중심 작업 습관을 보존한다.
2. cmux가 없어도 일반 shell, tmux, SSH, LazyVim에서 동작한다.
3. 새 장비에서 재현할 수 있고 partial failure를 탐지할 수 있다.
4. project/session/Agent/worktree의 source of truth를 하나로 만든다.
5. UI가 바뀌어도 core state와 automation contract는 유지한다.
6. 초기 구현 복잡도를 낮추고 필요가 입증되지 않은 daemon/desktop app은 미룬다.

## 검토한 대안

| 대안 | 변경량 | 통합 수준 | 장비 호환 | 유지 비용 | 판단 |
|---|---:|---:|---:|---:|---|
| A. 현재 구조 최소 개선 | 낮음 | 중간 | 높음 | 중간 | Phase 0·1에 활용 |
| B. 중앙 Workbench CLI | 중간 | 높음 | 높음 | 중간 | core로 채택 |
| C. 별도 Desktop/Web 앱 우선 | 높음 | 높음 | 중간 | 높음 | 선행안으로 기각 |
| D. LazyVim-native plugin 중심 | 중간 | 중간 | 중간 | 중간 | thin client로 채택 |
| E. Hybrid CLI + clients | 중간 | 높음 | 높음 | 중간 | 최종 기본안 |

### A. 현재 구조 최소 개선

`binbox` JSON 출력, aggregate doctor, compatible repo snapshot만 추가하고 새 core는 만들지 않는다.

- 장점: 가장 빠르고 기존 workflow를 거의 바꾸지 않는다.
- 단점: binbox가 project state와 provider logic을 함께 소유하며 장기적으로 비대해진다.
- 사용: Phase 0과 Phase 1의 안전한 중간 상태로 사용한다.

### B. 중앙 Workbench CLI

새 `workbench` repo와 `wb` CLI가 project/session/Agent/worktree를 관리한다.

- 장점: 모든 UI가 같은 API와 state를 사용한다.
- 단점: 새 schema, migration, compatibility 책임이 생긴다.
- 판단: 장기 core로 채택한다.

### C. 별도 Desktop/Web 앱 우선

GUI부터 만들고 shell/tmux/cmux를 제어한다.

- 장점: 여러 Agent와 worktree를 시각적으로 보기 좋다.
- 단점: backend 계약이 정리되지 않은 상태에서 UI에 shell logic이 중복된다.
- 판단: 순서가 잘못됐다. core 이후 optional client로만 검토한다.

### D. LazyVim-native plugin 중심

Neovim 안에서 project, Agent, worktree를 모두 관리한다.

- 장점: 현재 작업 습관과 가장 가깝다.
- 단점: Neovim이 꺼져 있거나 SSH shell만 있는 환경에서 control plane이 사라진다.
- 판단: state owner가 아닌 thin client로 사용한다.

### E. Hybrid CLI + clients

`wb`가 core, cmux/tmux가 backend, LazyVim/Web이 client, binbox가 provider가 된다.

- 장점: 환경 독립성과 통합 상태를 동시에 얻는다.
- 단점: contract를 먼저 설계하고 단계적으로 migration해야 한다.
- 판단: 기본안으로 채택한다.

## 목표 구조

```text
                       ┌──────────────────────┐
                       │ dev-env-setup        │
                       │ profile · lock       │
                       │ bootstrap · doctor   │
                       └──────────┬───────────┘
                                  │ provisions
                                  ▼
┌─────────────┐  JSON/commands  ┌──────────────────────┐  adapters  ┌─────────────┐
│ cmux actions├────────────────►│ workbench core (`wb`)├──────────►│ cmux        │
│ LazyVim UI  ├────────────────►│ projects · agents    ├──────────►│ tmux        │
│ Web UI      ├────────────────►│ sessions · worktrees ├──────────►│ git         │
│ shell/TUI   ├────────────────►│ events · capabilities├──────────►│ binbox      │
└─────────────┘                  └──────────────────────┘            └─────────────┘
```

## 역할 결정

### Workbench core

- authoritative project registry
- backend 선택과 session/worktree lifecycle
- Agent launch registry와 stable task ID
- versioned JSON contract
- local state backup/migration

### cmux

- 로컬 desktop workspace와 browser/notification UX
- `wb`를 호출하는 action과 generated workspace
- authoritative project/Agent state는 소유하지 않음

### tmux

- 장시간 session, SSH, reconnect
- pane metadata로 Workbench task와 연결
- local 일반 작업의 유일한 backend로 강제하지 않음

### LazyVim

- project/Agent/worktree picker와 편집 workflow
- `wb --json` 결과를 표시하고 action을 호출
- registry 파일이나 cmux JSON을 직접 해석하지 않음

### binbox

- Kubernetes, Terraform, AWS, tmux helper 등 provider command
- stable machine-readable output
- authoritative project/Agent state는 소유하지 않음

### Dashboard

- `wb dashboard`가 `127.0.0.1`의 임시 port에서 제공하는 local Web UI
- cmux in-app browser, 일반 browser 모두 사용 가능
- 나중에 필요하면 같은 local API를 Tauri/SwiftUI로 감쌈

## Backend 선택 규칙

명시적 option이 항상 우선한다.

```bash
wb open binbox --backend cmux
wb open binbox --backend tmux
wb open binbox --backend shell
```

`--backend`가 없을 때만 profile과 environment를 사용한다.

1. project override
2. active profile default
3. `CMUX_*` 환경 또는 cmux capability 감지
4. `TMUX` 또는 SSH 감지
5. shell fallback

자동 감지가 실패해도 명시적 backend는 동작해야 한다.

## 결정 기록

### ADR-001 — Workbench는 cmux 전용이 아니다

- 상태: 채택
- 결정: core는 headless CLI이며 cmux는 optional backend/client다.
- 이유: SSH, 다른 장비, tmux-only 환경에서도 동일한 project와 Agent 상태가 필요하다.
- 결과: cmux API가 없어도 project list, worktree, doctor, shell backend는 동작해야 한다.

### ADR-002 — UI보다 versioned contract를 먼저 만든다

- 상태: 채택
- 결정: JSON API와 exit code를 먼저 구현한다.
- 이유: UI를 먼저 만들면 cmux/LazyVim/Web에 shell parsing과 상태 logic이 중복된다.
- 결과: UI는 `wb` contract만 사용하고 내부 state file을 직접 읽지 않는다.

### ADR-003 — Dashboard는 localhost Web UI로 시작한다

- 상태: 조건부 채택
- 결정: `wb dashboard`를 우선하고 별도 desktop binary는 미룬다.
- 이유: cmux browser와 일반 browser에서 공통 사용 가능하며 배포 부담이 작다.
- 조건: loopback-only, random/explicit local port, arbitrary shell 입력 금지.

### ADR-004 — daemon은 필요가 입증될 때만 추가한다

- 상태: 채택
- 결정: 초기 core는 command 실행 시 state를 읽고 쓰는 단일 CLI다.
- 이유: daemon lifecycle, socket, upgrade, crash recovery 복잡도를 미룬다.
- 재검토: 실시간 Agent event나 여러 client의 동시 갱신 요구가 polling으로 감당되지 않을 때.

### ADR-005 — Runtime link는 실제 installer가 소유한다

- 상태: 채택
- 결정: child repo의 app/config link는 child installer가 소유한다.
- 예외: `~/binbox`는 setup repo checkout을 노출하는 orchestration alias이므로 parent가 유지한다.
- parent 유지: `~/home/setup/binbox → ~/binbox`
- binbox child: `~/.local/bin/bb`, shell rc
- nvim child: `~/.config/nvim`, `~/.tmux.conf`, local template
- cmux child: `~/.config/cmux/cmux.json`, Application Support files
- 결과: `repos.txt` migration 후 nvim/cmux의 parent `link_target`은 비우고 child `setup_cmd`만 실행한다.

## 재검토 조건

다음 중 하나가 확인되면 이 문서의 결정을 다시 검토한다.

- cmux가 project/Agent registry와 cross-backend API를 안정적으로 native 제공
- tmux와 cmux를 동시에 지원하는 비용이 개인 사용 이득보다 커짐
- 여러 장비 간 실시간 state synchronization이 필수 요구가 됨
- Dashboard가 native notification/menu bar 없이 실사용 요구를 충족하지 못함
- `wb` schema가 binbox command만으로 충분해 별도 core가 불필요하다고 검증됨
