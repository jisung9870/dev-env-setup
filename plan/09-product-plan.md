# Personal Workbench 제품 기획

- 결과 상태: **Phase 0~5 구현 완료, Phase 5 이후 Dashboard 편집·백그라운드 server·scheduler까지 구현 — Phase 6 다음**
- 기준일: 2026-08-10
- 기준 구현: workbench `371cdd0`
- 적용 범위: `dev-env-setup`, `workbench`, `binbox`, `lazyvim-config`, `cmux-config`
- 대상 독자: 사용자, 유지보수자, 후속 구현 Agent
- 문서 역할: 현재 제품 기능과 향후 방향의 기준서. 세부 계약과 구현 이력은 `plan/00`~`08` 및 각 저장소 문서를 따른다.

## 핵심 결론

Personal Workbench는 tmux와 LazyVim을 대체하는 프로젝트 관리 도구가 아니라 **terminal-first 개인
개발환경 운영 콘솔**이다. 실제 작업은 계속 tmux·LazyVim에서 수행하고, Workbench는 흩어진 세션·Task·
도구 상태를 관찰하고 정규화하여 Dashboard에서 한눈에 확인하고 정확한 위치로 복귀하게 한다.

저장소와 실행물은 현재 경계를 유지한다. 특히 Workbench는 선택적 관찰 계층이므로 설치되지 않았거나
실행되지 않아도 tmux·LazyVim·binbox의 기본 작업 흐름을 막지 않는다.

| 대상 | 포함 여부 | 결론 |
|---|---|---|
| `workbench` / `wb` | 포함 | observer/state core. managed 상태와 tmux 관찰 결과를 정규화 |
| Workbench Dashboard | 포함 | 현황·이상 상태·작업 위치·안전한 복귀를 제공하는 operations console |
| `binbox` / `bb` | 포함 | tmux·Git·Kubernetes·Terraform·AWS·보안 등의 독립 실행 toolbox로 유지 |
| tmux + LazyVim | 포함 | 키보드 중심의 canonical workspace로 유지 |
| cmux | 포함 | macOS의 선택적 workspace/client/backend로 유지 |
| `dev-env-setup` | 포함 | 설치·업데이트·호환 commit·aggregate 검증 owner로 유지 |
| 저장소 물리 합병 | 제외 | 현재는 이득보다 toolchain·platform·release 결합 비용이 큼 |

Phase 0의 회귀 조건은 다음과 같다.

1. tmux의 `|`, `-`, `c`, `f`, `a` 키 동작을 변경하지 않는다.
2. LazyVim의 `<leader>tp`(`bb tm`)와 `<leader>fp`(Workbench project picker)를 유지한다.
3. 주요 `bb` 도구의 실행 진입점을 유지한다.
4. Workbench 장애나 부재가 terminal 작업을 막지 않는다.
5. Session 관찰과 통합 Task의 provenance·confidence·소유권 구분을 유지하고, 관찰만으로 성공·실패를 단정하지 않는다.

## 제품 정의

### 목표

사용자가 terminal의 작업 방식을 바꾸지 않고도 여러 세션과 도구에 흩어진 상태를 확인하고 복귀하게 한다.

```text
tmux/LazyVim에서 작업
  → bb로 반복 명령 실행
  → Workbench Core가 상태를 관찰·정규화
  → Dashboard에서 세션·Task·도구 health 확인
  → 정확한 terminal 위치로 복귀
```

### 핵심 사용자 가치

- 익숙한 tmux 분할·새 창·project sessionizer와 LazyVim 편집 흐름을 그대로 유지한다.
- Workbench가 시작한 managed Task와 terminal에서 직접 실행한 observed Task를 구분한다.
- Codex와 Claude뿐 아니라 Terraform·Trivy 등 다시 찾아가야 하는 작업도 같은 Task 관점에서 본다.
- Git worktree를 Workbench가 만든 대상과 외부 대상을 구분해 안전하게 관리한다.
- Kubernetes, Terraform, AWS 같은 운영 도구는 `bb`의 빠른 Bash workflow를 그대로 활용한다.
- 새 장비와 장애 상황에서 어느 구성요소가 실패했는지 `doctor`와 contract test로 구분한다.

### 비목표

- `wb`와 `bb`를 하나의 바이너리 또는 하나의 저장소로 즉시 합치지 않는다.
- Workbench를 상시 daemon, 원격 서비스, 팀용 multi-user control plane으로 만들지 않는다.
- Workbench나 Dashboard를 tmux·LazyVim·binbox의 필수 선행 조건으로 만들지 않는다.
- Dashboard나 client에서 임의 shell command, path, prompt를 입력받아 실행하지 않는다.
- Bash 기반 binbox를 Go 또는 native Windows 구현으로 전면 재작성하지 않는다.
- 사용 근거가 없는 generic plugin/RPC/workflow framework를 먼저 만들지 않는다.

## 제품 책임과 데이터 흐름

```text
tmux + LazyVim ─────── canonical workspace
      │
      ├── binbox (`bb`) ─────── domain toolbox
      │
      └── Workbench Core ────── observer · normalized state · typed actions
                    │
                    └── Dashboard ── operations console

dev-env-setup ────── install · upgrade · lock · aggregate test
cmux ─────────────── optional macOS client/backend
```

### 소유권 원칙

| 정보/행동 | Canonical owner | 허용되는 consumer/fallback |
|---|---|---|
| pane 분할·window/session lifecycle·foreground process | tmux | Workbench는 읽고 stable identifier로 복귀만 요청 |
| 파일 탐색·편집·diagnostics | LazyVim | Workbench picker는 선택적 quick action |
| Project ID, path, profile | Workbench project registry | `bb tm` project sessionizer는 독립 terminal 진입점으로 유지 |
| managed Agent lifecycle와 task ID | Workbench Agent registry | 직접 실행한 작업은 observed로 표시하고 stop 권한 없음 |
| Worktree ownership | Git porcelain + Workbench managed ID | 외부 worktree는 표시만 하고 강제 삭제하지 않음 |
| Backend process/workspace | 각 backend | Workbench는 검증 가능한 reference만 보관 |
| Git/AWS/Kubernetes/Terraform/Secret/Trivy/Docker workflow | binbox | Workbench는 health를 집계하거나 allowlisted typed action으로 연결 가능 |
| 설치·repo commit 호환성 | dev-env-setup | child installer가 자기 runtime link를 소유 |

Workbench 내부 의존 방향은 `Dashboard/client → Workbench Core → observer/typed adapter`이다. 하지만
terminal workspace의 의존 방향은 Workbench를 통과하지 않는다. tmux·LazyVim·`bb`는 `wb` 없이도
각자의 기본 기능을 수행해야 한다.

## 현재 기능 기준선

상태 표기는 `제공`, `부분 제공`, `호환 경로`, `미제공`으로 통일한다.

| 사용자 영역 | 현재 상태 | 실제 제공 기능 | 남은 갭 |
|---|---|---|---|
| 설치·업데이트 | 제공 | 4개 child repo 선택, platform severity, bootstrap, upgrade, commit lock, aggregate doctor | 물리 Windows/WSL interactive smoke 미실행 |
| 프로젝트 registry | 제공 | CRUD, canonical path/portable ID, profile, JSON schema v1, sessionizer migration | legacy project source 제거 조건 확인 필요 |
| 프로젝트 열기 | 제공 | shell, tmux, cmux, Windows Terminal/WSL backend 선택과 명시적 override | tmux 외 backend의 session inventory는 없음 |
| Worktree core | 제공 | Git-verified list/create/remove, stable managed ID, dirty/lock/branch 안전장치 | client에서는 list/open 중심; create/remove UI 없음 |
| Agent core | 제공 | Codex/Claude start/list/show/jump/stop, task registry, tmux/cmux ownership 재검증 | `bb agents` scrape와 direct Agent launch fallback이 남음 |
| Dashboard | 제공 | 간결한 Overview와 `/projects`·`/activity`·`/settings`·`/system` 카테고리 route, 내장 Guide, typed open/start/jump/stop/history/workflow action, Environment metadata·export·Secret reference·expiry의 typed 편집, 활성 Profile의 검증된 원자적 교체, metadata-only Secret 카탈로그 | 실제 kube context 전환, project와 Environment의 연결 변경, backend 공통 session lifecycle은 미제공 |
| LazyVim client | 제공 | Projects, Agents, Worktrees, Doctor 비동기 picker; Agent jump/stop; worktree 파일 열기 | project 조회에 `bb`와 sessionizer fallback 유지 |
| cmux client | 부분 제공 | generated Open/Start Agent action, Dashboard/Agents/Doctor, DevOps 작업판 | action 재생성이 수동이고 현재 검증 장비에는 cmux 실행 파일 없음 |
| binbox provider | 제공 | tmux/Git/Kubernetes/AWS/Terraform/secret/Trivy/Docker workflow와 자체 doctor/check | project/Agent 명령 일부가 Workbench와 과도기 중복 |
| Session 관찰과 tmux 소유권 | 제공 | `wb sessions list/show/jump/attach/adopt/stop`, tmux session/window/pane snapshot과 stable pane 복귀, tmux user option에 저장되는 managed/legacy/foreign 소유권, adopt 시 이름·start path 검증과 stop 직전 소유권 재검증, optional unavailable 처리 | tmux 외 backend의 공통 session registry/lifecycle은 미제공; tmux가 여전히 실제 lifecycle owner |
| 통합 Task | 제공 | Workbench managed Agent/workflow와 tmux에서 직접 실행한 Codex/Claude/OMC/OMX observed Task 통합, provenance/confidence/ownership 구분 | Terraform·Trivy 등 non-AI direct process classifier는 미제공 |
| Typed workflow | 제공 | allowlisted project test/Trivy scan/Terraform plan, detached tmux worker, metadata-only bounded history, ownership-verified jump | arbitrary command와 apply/destroy/Secret 평문 작업은 의도적으로 미제공 |
| Environment registry | 제공 | schema-v1 `wb env` list/show/add/expiry/remove/health/export, `--ttl`·`--expires-at` 절대 만료와 `wb env expiry` 갱신·해제, `wenv.d` check/apply migration, AWS·일반 변수 export | 실제 kube context/namespace 전환은 미제공 |
| Local Secret | 제공 | age Go library 기반 `wb secrets` init/list/set/get/edit/copy/remove, mode-0600 임시 파일을 쓰는 editor 편집, stdin 경유 클립보드 복사와 해시 확인 후 조건부 자동 삭제, 명시적 replace·확인·backup·cross-process lock, legacy `sec` check/apply migration | passphrase identity, ASCII armor, 전체 store 편집, Dashboard 평문 접근은 미제공 |
| Project Environment 연결 | 제공 | project의 optional `environment_id`, 실행 시 override/disable, registry reference 검증 | Dashboard에서 연결을 변경하는 UI는 미제공 |
| Workflow 환경 주입 | 제공 | detached worker가 실행 직전 environment를 재조회하고 opt-in Secret을 memory에서 해석·redact하여 subprocess에 주입 | 변형·인코딩·파일·network 유출을 막는 sandbox는 아님 |
| Context health와 편집 | 제공 | 선택 project의 Environment metadata, export key 이름, Secret 변수 이름과 available/missing 상태 표시, metadata·일반 export·Secret reference·expiry의 typed 편집 | raw reference/service/field/path/평문 렌더링과 평문 입력 필드는 의도적으로 미제공 |
| 백그라운드 Dashboard server | 제공 | `wb server start/status/stop`, mode-0600 runtime record와 log, 인증된 loopback readiness probe, stale·PID 재사용 record 거부, runtime-only control token 기반 graceful stop | 상시 daemon 자동 기동과 로그인 시 자동 실행은 의도적으로 미제공 |
| 로컬 scheduler와 activity history | 제공 | 백그라운드 server가 `environment-expiry-scan`과 `activity-scan`을 즉시 1회 후 분당 1회 실행, Agent·workflow·Environment expiry 상태 전이를 mode-0600 원자적 200건 history에 기록, job 실패를 HTTP serving과 격리해 `wb server status --json`과 Scheduler 패널에 노출 | foreground `wb dashboard`는 history를 읽기만 하고 scheduler는 unavailable로 보고; 명령 출력·Secret·환경 값·파일 경로는 기록하지 않음 |
| 공개 배포 | 미제공 | local source build와 setup 설치 | tagged release, versioned compatibility 문서, public distribution 미정 |

### 2026-08-10 현재 운영 확인

Workbench 구현 이력은 `2ad89cd`(Phase 0~4), `dfaa40b`(Environment migration), `8fd7c96`(local Secret),
`f96e9a9`(project Secret reference), `cc5b340`(workflow 환경 주입), `39100f2`(Dashboard Context health),
`7591c15`(managed session과 백그라운드 server), `215c28e`(Environment expiry scheduler),
`2e97f6d`(Dashboard Environment 편집), `aa24d3d`(Dashboard Secret 관리와 클립보드),
`aa00143`(Dashboard Profile 관리), `344f8b1`(activity center), `371cdd0`(Dashboard navigation 정리)다.

기준 구현 `371cdd0`에서 실행한 검증 결과다.

| 검증 | 명령 | 결과 |
|---|---|---|
| Workbench 정적 분석 | `make vet` | 통과 |
| Workbench 단위·통합 test | `make test` | 전 패키지 통과 |
| Windows cross-compile | `GOOS=windows GOARCH=amd64 go build ./cmd/wb` | 통과 |
| Cross-repo 계약 | `./tests/contract-test.sh` | 18 group 통과 |
| 설치·repo 건강 | `./doctor.sh` | `environment healthy` |
| 통합 E2E | `tests/workbench-e2e.sh` | 갱신 후 11 group 통과 |

이번 회차에 확인한 사실과 남은 한계는 다음과 같다.

- 통합 E2E는 기준 구현에서 처음에 실패했고, 원인은 workbench 변경이 아니라 루트 E2E의 계약 노후였다.
  같은 E2E가 이전 구현 `6bca9f9`에서는 10 group 전부 통과한다.
- 첫 번째 원인은 가짜 tmux fixture가 `sessions.Ensure` 경로의 `list-sessions`, `show-options`,
  `list-panes`, `kill-session`, session 범위 `set-option`을 모르는 것이었다. fixture를 확장했다.
- 두 번째 원인은 pane 소유권 불일치 시의 task 상태 계약 변경이다. 아래 실패 모드 표에 반영했다.
- 세 번째로 session 생성 실패 시 provider의 stdout과 exit code가 더 이상 전달되지 않는 것을 확인했다.
  실패 판정 자체는 정상이므로 진단 정보 손실이며, 아래 문제 6번에서 판정 대상으로 다룬다.
- race detector는 이번 회차에 실행하지 않았다. 이전 Phase 구현 시점의 통과 기록으로 대체하지 않는다.
- 변형·인코딩된 값, file/network 채널의 유출 방지는 sandbox 범위가 아니며 검증 완료로 간주하지 않는다.
- 물리 Linux/Windows/WSL 및 실제 cmux 장비 smoke는 아직 수행하지 않았다. Windows cross-compile 통과를
  물리 장비 smoke로 대체하지 않는다.

## 현재 문제와 제품 기회

### 1. terminal 작업과 관찰 상태의 경계가 아직 불명확하다

`wb projects`와 `bb tm projects`, Workbench Agent registry와 `bb agents`, `wb doctor`와 `bb doctor`가
동시에 노출된다. 이것은 모두 제거할 중복이 아니다. `bb tm`은 terminal workspace 진입이고,
Workbench registry와 Dashboard는 정규화된 상태와 관찰 화면이다. `bb agents`는 Workbench observer가
직접 실행 작업까지 충분히 보여주기 전까지 terminal fallback으로 유지한다.

**방향:** 실행 UX와 상태 책임을 명령 이름이 아니라 소유권으로 구분한다. Workbench가 같은 도메인을
관찰하더라도 tmux·LazyVim·binbox의 독립 실행 경로를 자동으로 폐기하지 않는다.

### 2. tmux 소유권은 생겼지만 backend 공통 session lifecycle은 여전히 갭이다

Workbench는 사용자가 직접 만든 tmux session/window/pane을 읽고 stable pane으로 복귀하며, 자신이 만들었거나
명시적으로 adopt한 project session에 한해 tmux user option 기반 소유권을 가진다. managed Agent/workflow와
알려진 AI CLI observed Task도 같은 화면에서 구분한다. 다만 소유권은 tmux에 한정되고 cmux·Windows Terminal을
아우르는 공통 session registry나 lifecycle owner는 아니다.

**방향:** tmux가 실제 lifecycle owner라는 경계를 유지하고, Workbench 소유권은 이름과 canonical start path가
검증된 project session에만 부여한다. non-AI observed classifier와 다른 backend의 session inventory는 실제
사용 근거와 신뢰 가능한 식별자가 생길 때 별도 확장한다.

### 3. cmux project action이 registry와 자동으로 동기화되지 않는다

cmux action은 안전한 stable project ID만 보관하지만 project add/remove 후 생성 스크립트를 수동으로
실행해야 한다. 오래된 action은 source-of-truth 원칙을 약화한다.

**방향:** cmux-config가 `sync-workbench` 단일 명령을 소유하게 하고 setup/upgrade에서 실행한다.
`doctor`와 CI에서는 `generate-workbench.py --check`로 drift를 탐지한다. `wb` core가 cmux 설정 파일을
직접 수정하지는 않는다.

### 4. Worktree 변경 기능이 CLI에만 있다

core의 안전장치는 구현됐지만 LazyVim과 cmux는 list/open 또는 project/Agent action 중심이다.

**방향:** 먼저 LazyVim에 create/remove를 추가하고 실제 사용성을 확인한 뒤 Dashboard/cmux로 확장한다.
모든 client는 branch, base, managed ID 같은 typed field만 전달하며 dirty/locked/unmerged 거부와 확인
절차는 core가 계속 소유한다.

### 5. 계획 문서에 현재 상태와 구현 이력이 섞여 있다

기존 `plan/`은 의사결정과 상세 구현 근거는 충분하지만 초기 상태, 완료 로그, 현재 기능이 여러 파일에
누적됐다.

**방향:** 이 문서를 제품 기준서로 사용하고 `00`~`08`은 배경·계약·구현 이력으로 유지한다. 기능 또는
방향이 바뀌면 먼저 이 문서의 현재 기능 표와 로드맵을 갱신한 뒤 세부 문서를 변경한다.

### 6. session 생성 실패 시 provider 진단 정보가 사라진다

`wb open`과 Agent 실행은 이제 `sessions.Ensure`를 거친다. 이 경로가 실패하면 tmux adapter와 Agent runtime이
빈 `ProcessResult`를 반환하므로(`workbench/adapters/tmux/tmux.go:211`,
`workbench/internal/agents/runtime.go:118`) 실패한 backend 프로세스의 stdout과 exit code가 사용자에게
전달되지 않고 wrapping된 오류 문자열만 남는다. 이전 구현은 실패한 프로세스 결과를 그대로 전달했다. 실패를
실패로 판정하는 계약은 유지되지만 운영자는 provider가 실제로 무엇을 출력했는지 볼 수 없다.

**방향:** Phase 6 착수 전에 판정한다. 기본안은 `Ensure`가 실패한 `ProcessResult`를 함께 반환해 이전 수준의
진단 정보를 복원하는 것이다. 현재 동작을 계약으로 확정한다면 그 근거를 이 문서와 backend 계약 문서에 함께
기록한다. 어느 쪽이든 통합 E2E가 그 계약을 직접 검증해야 한다.

## 방향성 결정

| 결정 | 상태 | 근거와 영향 |
|---|---|---|
| terminal-first operations console | 채택 | tmux·LazyVim 작업을 보존하면서 모니터링·가독성·복귀 문제 해결 |
| Workbench Core observer/state / Dashboard ops console | 채택 | 관찰 결과와 owned state를 구분해 한 화면에서 제공 |
| `bb` toolbox 경계 | 채택 | 빠른 Bash operator workflow와 독립 CLI 진입점을 보존 |
| 저장소 물리 합병 | 보류 | 현재는 independent install/platform/test 가치가 더 큼 |
| fallback의 관찰 후 제거 | 채택 | clean-machine 호환성과 rollback 경로를 증거 없이 제거하지 않음 |
| tmux session read-only 관찰 | 채택 | 실제 lifecycle은 tmux가 소유하고 Workbench는 snapshot과 jump만 제공 |
| Workbench optionality | 채택 | 관찰 계층 장애가 terminal 작업을 막지 않음 |
| cmux action sync를 cmux-config가 소유 | 제안 | client 설정 ownership을 지키면서 registry drift를 탐지·복구 |
| arbitrary workflow 실행 | 기각 | local UI의 보안·예측 가능성 경계를 훼손 |
| 외부 Vault 전환 | 기각 | 개인 도구의 관리 지점을 늘리지 않고 Workbench-owned local encrypted store 유지 |
| Dashboard Contexts의 typed metadata 편집 | 채택(2026-08-10 갱신) | 기존 read-only 결정을 대체한다. metadata·일반 export·Secret reference·expiry만 typed action으로 편집하고, 평문은 요청 전용 필드로만 받으며 응답과 DOM에는 렌더링하지 않는다 |
| Secret 클립보드·editor 접근을 CLI에만 제공 | 채택 | 평문 취급을 terminal 경계 안에 두고 stdin 전달, mode-0600 임시 파일, 해시 확인 후 조건부 자동 삭제로 노출 창을 제한한다 |
| 명시적으로 시작하는 백그라운드 server와 로컬 scheduler | 채택 | 상시 daemon 없이 사용자가 시작한 프로세스 안에서만 주기 job을 실행하고, job 실패를 HTTP serving과 분리해 관측 가능하게 만든다 |
| pane 소유권 불일치를 stopped로 reconcile | 채택 | 잘못된 pane을 조작하는 위험을 제거하는 대신, 살아 있는 프로세스를 Workbench가 더 이상 제어하지 못하는 비용을 감수한다. 아래 실패 모드 표를 함께 본다 |

저장소 합병은 다음 조건이 반복적으로 확인될 때만 재검토한다.

- 대부분의 변경이 두 repo의 동시 commit과 동시 release를 요구한다.
- binbox의 독립 사용과 Bash-only 배포 가치가 사라진다.
- Windows 배포에서 provider 포함/제외 경계를 단순하게 유지할 수 있다.
- versioned JSON과 aggregate test보다 monorepo가 실제 장애와 운영 비용을 더 많이 줄인다는 근거가 있다.

재검토하더라도 하나의 바이너리가 아니라 한 저장소 안의 독립 `wb`와 `bb` 실행물 구조를 우선한다.

## 단계별 로드맵

로드맵은 `.omx/plans/personal-development-operations-console.md`를 상세 기준으로 하며, 한 단계의
수용 조건과 회귀 검증을 통과한 뒤 다음 단계로 이동한다.

| Phase | 상태 | 목표 | 핵심 완료 조건 |
|---:|---|---|---|
| 0 | 완료 | 기준선과 용어 고정 | owner 표, tmux/LazyVim/`bb` 회귀 계약, Workbench optionality 문서화 |
| 1 | 완료 | tmux read-only Session 관찰 | session/window/pane snapshot, stable pane jump, unavailable을 optional로 처리 |
| 2 | 완료 | managed/observed Task 통합 | provenance·confidence 보존, 직접 실행 AI CLI 관찰, exit 미상 상태의 정직한 표현 |
| 3 | 완료 | Overview와 Tool health | 작업 위치·이상 상태 요약, `bb doctor --json` optional provider 집계 |
| 4 | 완료 | allowlisted typed workflow | 임의 shell 금지, tests/scan/plan의 detached tmux 실행과 metadata-only 결과 기록 |
| 5 | 완료 | Environment와 local Secret | `wenv`·`sec` migration, project 연결, workflow 주입, Context health와 평문 비노출 계약 |
| 5+ | 완료 | Phase 5 이후 추가 구현 | tmux session 소유권, 백그라운드 server와 로컬 scheduler, activity history, Dashboard의 Environment·Secret·Profile typed 편집, Dashboard navigation 정리 |
| 6 | 다음 | fallback 정리와 배포 판정 | 관찰 증거가 있는 shim만 제거하고 physical cross-platform smoke를 별도 기록 |

Observed Task의 exit code를 알 수 없으면 성공·실패를 확정하지 않는다. Phase 4 이후에도 Dashboard에
arbitrary command runner를 만들지 않는다. Phase 5의 수용 조건은 CLI store·migration·선택적 subprocess
주입과 Context health까지였고, `5+`로 표시한 Dashboard typed 편집·expiry·백그라운드 server는 그 조건을
넘어 추가로 구현한 범위다. 실제 kube context 전환은 여전히 범위 밖이다.

## 실패 모드와 호환성 원칙

| 실패 모드 | 탐지 | 기본 동작 | 복구/롤백 |
|---|---|---|---|
| `wb` 없음 또는 schema mismatch | LazyVim error, Doctor | project만 명시적 fallback; 다른 state는 unavailable | 함께 호환되는 repo lock으로 복구 |
| legacy fallback이 primary 실패를 숨김 | compatibility latest source | fallback source와 오류를 노출 | primary 복구 후 대표 흐름 재실행 |
| stale cmux action | generator `--check` | 오래된 action 배포를 실패 처리 | `sync-workbench` 후 config rebuild |
| Agent backend reference drift | `Alive`/ownership 재검증 | jump/stop 거부 | task 상태 reconcile, terminal history 보존 |
| pane 소유권 불일치 | pane user option의 task ID 비교 | 해당 task를 `completed`로 확정하고 이후 jump과 stop을 모두 거부 | 프로세스가 실제로 살아 있으면 terminal에서 직접 정리한다. Workbench는 그 pane을 다시 소유하지 않는다 |
| session 생성 실패 | backend 프로세스 exit code | 실패로 판정하고 open/start를 중단 | 현재는 provider stdout이 전달되지 않으므로 같은 명령을 terminal에서 직접 실행해 원인을 확인한다(문제 6번) |
| dirty/locked worktree | Git porcelain 재검증 | remove 거부 | 변경 정리 또는 사용자가 Git에서 명시적으로 처리 |
| optional provider/backend 없음 | scoped Doctor status | core는 healthy 유지 | 설치 안내 또는 다른 backend 선택 |
| required repo/setup 실패 | root bootstrap/doctor | aggregate 실패, partial result 표시 | clean checkout/lock 확인 후 해당 child 재실행 |

## 보안·운영 체크리스트와 2차 영향

### 유지해야 할 통제

- state owner를 하나로 유지하고 client가 registry 파일을 직접 수정하지 않는다.
- command와 ID는 argument array와 typed field로 전달한다.
- Dashboard는 loopback-only, same-origin token, body limit, restrictive CSP를 유지한다.
- worktree/Agent stop·remove는 실행 직전 ownership과 현재 상태를 다시 검증한다.
- machine-local path, prompt, secret, task ID를 generated config나 screenshot에 불필요하게 복사하지 않는다.
- config와 runtime state를 분리하고 변경 전 backup과 recovery path를 유지한다.

### 2차 영향

- fallback을 너무 빨리 제거하면 clean machine과 오래된 client에서 project 진입 자체를 잃을 수 있다.
- 반대로 fallback을 오래 유지하면 primary 장애가 가려지고 두 상태 모델의 유지 비용이 계속 발생한다.
- cmux sync를 `wb`에 직접 넣으면 core가 client config ownership을 침범하고 Windows/Linux 배포가 복잡해진다.
- binbox를 Workbench 내부로 넣으면 빠른 script 수정성은 줄고 Windows에서 사용할 수 없는 provider가 core release를 묶는다.
- worktree mutation UI가 core safety를 우회하면 dirty 변경 손실 위험이 커지므로 UI 편의보다 거부 계약을 우선한다.

## 관찰과 수용 기준

| 확인 항목 | 확인 위치/명령 | 담당 역할 | 확인 시점 | 수용 기준 |
|---|---|---|---|---|
| Repo와 설치 건강 | `./doctor.sh` | 환경 유지보수자 | bootstrap/upgrade 후 | required failure 0, lock mismatch 설명 가능 |
| Cross-repo 계약 | `./tests/contract-test.sh` | 변경 구현자 | fallback 제거·release 전 | 전체 group와 child test 성공 |
| terminal UX 기준선 | `./tests/contract-test.sh --root-only` | 환경 유지보수자 | 모든 Phase 종료 | tmux `\|`, `-`, `c`, `f`, `a` 키, LazyVim project key, 주요 `bb` entrypoint 유지 |
| Workbench core | `wb doctor --strict` | Workbench 유지보수자 | core/state 변경 후 | unavailable core 0 |
| Workbench optionality | static contract + Workbench 없는 shell smoke | 환경 유지보수자 | dependency 변경 후 | `bb tm`, `bb` toolbox, tmux/LazyVim 기본 경로 유지 |
| managed/observed 구분 | Workbench Task contract | Workbench 유지보수자 | Phase 2 이후 | provenance와 confidence를 잃지 않음 |
| cmux config drift | `generate-workbench.py --check`, config check | cmux-config 유지보수자 | project registry 변경·upgrade 후 | generated action 최신, reference 검사 성공 |
| Worktree 안전 | CLI/client contract test | Workbench·client 구현자 | mutation UI 변경 후 | dirty/locked/unmerged와 외부 worktree 거부 유지 |
| Windows/WSL 지원 | physical smoke 기록 | 환경 유지보수자 | Tier 1 지원 완료 판정 전 | bootstrap/doctor/editor/tmux/Agent/worktree 대표 흐름 성공 |
| Environment/Secret 비노출 | Workbench tests + browser Context 확인 | Workbench 유지보수자 | 관련 contract 변경 후 | argv/history/Dashboard JSON/browser에 평문 0건 |
| 기준 구현 통합 E2E | `tests/workbench-e2e.sh` | 환경 유지보수자 | Phase 6 착수·release 판정 전 | `371cdd0`에서 11 group 성공 |

관찰 기간은 고정 일수가 아니라 위 대표 흐름의 완주 여부로 정한다. 월간·배치성 기능이 아닌 개인
개발환경이므로, 각 지원 client/backend에서 실제 project·Agent·worktree 흐름을 최소 한 번 끝까지 수행한
결과가 fallback 제거 판단의 기준이다. 미실행 환경은 성공으로 간주하지 않는다.

## 즉시 실행할 다음 행동

| 순서 | 행동 | 상태 | 담당 역할 | 착수/완료 기준 |
|---:|---|---|---|---|
| 1 | terminal-first 제품 경계와 owner 표 고정 | 완료 | 문서 유지보수자 | README와 이 문서가 같은 역할 구분 사용 |
| 2 | tmux/LazyVim/`bb` 정적 회귀 계약 추가 | 완료 | 환경 유지보수자 | root-only contract 통과 |
| 3 | tmux read-only observer와 `wb sessions` 구현 | 완료 | Workbench 구현자 | Phase 1 fixture·실 tmux 수용 조건 통과 |
| 4 | managed/observed Task 통합 | 완료 | Workbench 구현자 | Phase 2 provenance·confidence 계약 통과 |
| 5 | Dashboard Overview와 Tool health | 완료 | Workbench/binbox 구현자 | Phase 3 optional provider 계약 통과 |
| 6 | allowlisted typed workflow | 완료 | Workbench 구현자 | detached tmux worker·보안·metadata-only history 계약 통과 |
| 7 | Environment와 local Secret 통합 | 완료 | Workbench/binbox 구현자 | migration·project 연결·workflow 주입·read-only Context·평문 비노출 계약 통과 |
| 8 | 기준 구현 통합 E2E 결과 확정 | 완료 | 환경 유지보수자 | `371cdd0`에서 vet·test·Windows cross-compile·contract·doctor·E2E 성공 기록 |
| 9 | session 생성 실패 시 provider 진단 정보 판정 | 다음 | Workbench 구현자 | 문제 6번의 두 선택지 중 하나를 채택하고 통합 E2E가 그 계약을 직접 검증 |
| 10 | fallback 정리와 배포 판정 | 대기 | 환경 유지보수자 | Phase 6 관찰 근거와 physical Linux/Windows/WSL/cmux smoke 확보 |

## 가정과 미확인 사항

- 이 제품은 현재 단일 사용자의 로컬 개발환경을 대상으로 한다.
- 사용 빈도와 release cadence의 정량 데이터는 아직 없다. 저장소 합병과 daemon 도입 근거로 사용하지 않는다.
- 현재 장비의 compatibility primary 관찰은 긍정적이지만 다른 장비의 사용을 증명하지 않는다.
- cmux config 구현과 tests는 존재하지만 현재 검증 장비에는 cmux executable이 없어 live backend 동작은 미확인이다.
- 물리 Linux/Windows/WSL smoke는 미확인이다. cross-build나 fixture 결과로 대체하지 않는다.
- 물리 cmux smoke도 미확인이다. browser fixture나 config test로 대체하지 않는다.
- 통합 E2E는 가짜 tmux fixture 위에서 실행한다. 실제 tmux server의 동작을 증명하지 않으므로 physical
  smoke를 대신하지 않는다.
- Dashboard의 Environment·Profile typed 편집은 handler test와 통합 E2E의 loopback 계약까지만 검증했다.
  브라우저에서 각 편집 폼을 끝까지 수행한 수용 확인은 아직 기록하지 않았다.
- `wb secrets copy`의 조건부 자동 삭제는 단위 수준에서만 확인했고, 다른 프로그램이 클립보드를 덮어쓴
  상황의 실기기 확인은 미실행이다.

## 근거 문서

- [결정과 목표 아키텍처](01-decisions-and-target-architecture.md)
- [Workbench CLI와 데이터 계약](02-workbench-cli-and-data-contracts.md)
- [UI와 client spec](03-ui-and-client-spec.md)
- [구현 로드맵](04-implementation-roadmap.md)
- [저장소 변경 지도](05-repository-change-map.md)
- [검증·보안·운영](06-validation-security-operations.md)
- [Phase 4 cleanup plan](08-phase4-cleanup-plan.md)
- [Workbench README](../workbench/README.md)
- [Workbench Dashboard](../workbench/docs/dashboard.md)
- [Workbench backend contract](../workbench/docs/backend-contract.md)
- [binbox README](../binbox/README.md)
- [binbox ROADMAP](../binbox/ROADMAP.md)
- [LazyVim Workbench help](../nvim/doc/nvim-workbench.txt)
- [cmux-config README](../cmux-config/README.md)
- [dev-env-setup README](../README.md)
