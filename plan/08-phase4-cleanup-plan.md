# Phase 4 cleanup plan

## 목표와 범위

Phase 4의 첫 pass는 project source of truth 중복을 제거했다. 두 번째 pass는 Agent와 LazyVim
compatibility path를 삭제하지 않고, 실제 선택 source를 Workbench doctor가 판단할 수 있는 bounded local
observation으로 기록한다.

## Behavior lock

변경 전후 다음 계약을 고정한다.

- `wb projects list --json`에서 생성된 project action과 menu가 stable ID 순서로 유지된다.
- 생성 action에는 machine-local project path가 포함되지 않고 explicit `--backend cmux`가 유지된다.
- `cmux.json`은 source fragment에서 재생성 가능하며 reference/sensitive 검사를 통과한다.
- `workspaceGroups.newWorkspacePlacement = afterCurrent`는 유지된다.
- source fragment와 생성된 `cmux.json`에는 `workspaceGroups.byCwd` project root registry가 남지 않는다.

## 냄새와 fallback 분류

| 항목 | 분류 | 이번 pass |
|---|---|---|
| `cmux-config/config.d/base/workspace-groups.json`의 `byCwd` 경로 목록 | 중복 책임·hardcoded path | 제거 |
| generated Workbench project actions | canonical consumer | 유지하고 회귀 테스트 강화 |
| LazyVim `wb → bb JSON → sessionizer` | grounded compatibility fallback | 유지; doctor 사용 관찰이 먼저 필요 |
| binbox `agents --json` pane scraping | grounded compatibility fallback | 유지; `state_source=scrape`, 무권한 계약 보존 |
| nvim OS/runtime installer | 경계 이전 후보 | 별도 pass로 연기 |
| parent/child runtime links | 현재 코드와 문서가 일치 | 검증만 수행 |

LazyVim과 binbox fallback은 primary path 실패를 숨기지 않고 source/error를 노출하며 회귀 테스트가 있다.
따라서 masking fallback으로 보지 않는다. 사용 주기 관찰 없이 삭제하면 rollback 경로와 clean-machine
호환성을 잃으므로 이번 pass에서 제거하지 않는다.

## 실행 순서

1. cmux test에 `byCwd` 부재와 global placement 유지 계약을 추가한다.
2. hardcoded `workspaceGroups.byCwd`를 삭제한다.
3. README/guide에서 경로별 색상 그룹 설명을 제거하고 Workbench-generated project action을 source of truth로 명시한다.
4. `cmux.json`을 재생성한다.
5. cmux targeted 검사 후 root aggregate contract와 doctor를 실행한다.
6. child SHA, Phase 상태, handoff를 갱신한다.

## Rollback

cmux fragment와 생성된 `cmux.json` commit을 revert하면 경로별 group metadata가 복원된다. project open은
정리 전후 모두 generated Workbench action과 explicit cmux backend를 사용하므로 registry/state migration은
필요하지 않다.

## 후속 pass 진입 조건

- LazyVim direct parser: doctor가 fallback 사용 여부를 표시하고 대표 workflow 주기 동안 사용이 없어야 한다.
- legacy Agent scraping: Workbench registry가 지원 장비의 Agent 목록을 모두 제공하고 scrape 사용이 없어야 한다.
- installer 책임 이전: macOS/WSL clean-profile fixture에서 dev-env profile과 child installer의 소유권을 먼저 고정한다.

## Pass 2 — fallback 관찰 계약

- Workbench는 `nvim/projects/{workbench,binbox,sessionizer}`와
  `{workbench/agents/registry,binbox/agents/scrape}` 다섯 tuple만 저장한다.
- 외부 CLI는 네 consumer tuple만 허용하고 internal registry tuple은 `wb agents list` 성공 후 Workbench가 직접 기록한다.
- 각 tuple은 `${XDG_STATE_HOME}/workbench/compatibility` 아래 별도 mode-0600 JSON으로 atomic replace하며
  directory는 mode 0700이다. backup, daemon, network telemetry는 만들지 않는다.
- Neovim과 binbox observer는 비동기·출력 억제·best effort이며 기존 workflow 결과를 바꾸지 않는다.
- doctor는 미관찰을 `skipped`, 최신 primary를 `available`, 최신 fallback을 optional `unavailable`로 표시한다.
- timestamp는 advisory evidence다. clock rollback과 미실행 장비가 있으므로 자동 삭제 근거로 사용하지 않는다.

Pass 2 구현 후에도 fallback은 유지한다. 다음 pass에서 대표 사용 주기를 실제로 수행하고 두 compatibility
capability가 primary `available`인지 확인한 뒤에만 제거 후보를 다시 평가한다.
