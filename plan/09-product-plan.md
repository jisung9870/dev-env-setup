# Personal Workbench 제품 기획

- 결과 상태: **Phase 0~5 구현 완료 — Phase 6 다음**
- 기준일: 2026-08-07
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
| 프로젝트 열기 | 제공 | shell, tmux, cmux, Windows Terminal/WSL backend 선택과 명시적 override | backend별 session inventory는 없음 |
| Worktree core | 제공 | Git-verified list/create/remove, stable managed ID, dirty/lock/branch 안전장치 | client에서는 list/open 중심; create/remove UI 없음 |
| Agent core | 제공 | Codex/Claude start/list/show/jump/stop, task registry, tmux/cmux ownership 재검증 | `bb agents` scrape와 direct Agent launch fallback이 남음 |
| Dashboard | 제공 | operations Overview, project/Task/session/worktree/Git/Doctor/binbox health, typed open/start/jump/stop/history/workflow action, 내장 Guide, 선택 project의 read-only Contexts | Environment/Secret 수정, kube context 변경, common cross-backend session lifecycle은 미제공 |
| LazyVim client | 제공 | Projects, Agents, Worktrees, Doctor 비동기 picker; Agent jump/stop; worktree 파일 열기 | project 조회에 `bb`와 sessionizer fallback 유지 |
| cmux client | 부분 제공 | generated Open/Start Agent action, Dashboard/Agents/Doctor, DevOps 작업판 | action 재생성이 수동이고 현재 검증 장비에는 cmux 실행 파일 없음 |
| binbox provider | 제공 | tmux/Git/Kubernetes/AWS/Terraform/secret/Trivy/Docker workflow와 자체 doctor/check | project/Agent 명령 일부가 Workbench와 과도기 중복 |
| Session 관찰 | 제공 | `wb sessions list/jump`, tmux session/window/pane read-only snapshot, stable pane 복귀, optional unavailable 처리 | backend 공통 session registry/lifecycle은 미제공; tmux가 실제 lifecycle owner |
| 통합 Task | 제공 | Workbench managed Agent/workflow와 tmux에서 직접 실행한 Codex/Claude/OMC/OMX observed Task 통합, provenance/confidence/ownership 구분 | Terraform·Trivy 등 non-AI direct process classifier는 미제공 |
| Typed workflow | 제공 | allowlisted project test/Trivy scan/Terraform plan, detached tmux worker, metadata-only bounded history, ownership-verified jump | arbitrary command와 apply/destroy/Secret 평문 작업은 의도적으로 미제공 |
| Environment registry | 제공 | schema-v1 `wb env` list/show/add/remove/health/export, `wenv.d` check/apply migration, AWS·일반 변수 export | kube context/namespace mutation과 expiry 정책은 미제공 |
| Local Secret | 제공 | age Go library 기반 `wb secrets` init/list/set/get/remove, 명시적 replace·확인·backup·cross-process lock, legacy `sec` check/apply migration | passphrase identity, clipboard/editor, Dashboard 평문 접근은 미제공 |
| Project Environment 연결 | 제공 | project의 optional `environment_id`, 실행 시 override/disable, registry reference 검증 | Dashboard에서 연결을 변경하는 UI는 미제공 |
| Workflow 환경 주입 | 제공 | detached worker가 실행 직전 environment를 재조회하고 opt-in Secret을 memory에서 해석·redact하여 subprocess에 주입 | 변형·인코딩·파일·network 유출을 막는 sandbox는 아님 |
| Context health | 제공 | 선택 project의 Environment metadata, export key 이름, Secret 변수 이름과 available/missing 상태만 표시 | raw reference/service/field/path/평문 및 mutation action은 의도적으로 미제공 |
| 공개 배포 | 미제공 | local source build와 setup 설치 | tagged release, versioned compatibility 문서, public distribution 미정 |

### 2026-08-07 현재 운영 확인

- Workbench 구현 이력은 `2ad89cd`(Phase 0~4), `dfaa40b`(Environment migration),
  `8fd7c96`(local Secret), `f96e9a9`(project Secret reference), `cc5b340`(workflow 환경 주입),
  `39100f2`(Dashboard Context health)다.
- 각 구현 시점에 full tests, race, vet, Windows cross-compile, root contract를 통과했다.
- 실제 detached workflow와 browser Contexts 동작도 별도 수용 확인을 통과했다.
- 현재 HEAD `39100f2` 통합 E2E는 wenv check 무변경/apply+backup, Secret init/set/health/pipe resolve,
  project 기본 Environment, detached tmux Environment+Secret 주입, 성공 상태, stdout/stderr exact-value redaction,
  `--no-environment`, Secret 제거 후 pre-start 거부, Dashboard metadata-only Contexts와 cleanup/git clean을 확인했다.
- 변형·인코딩된 값, file/network 채널의 유출 방지는 sandbox 범위가 아니며 검증 완료로 간주하지 않는다.
- 물리 Linux/Windows/WSL 및 실제 cmux 장비 smoke는 아직 수행하지 않았다.

## 현재 문제와 제품 기회

### 1. terminal 작업과 관찰 상태의 경계가 아직 불명확하다

`wb projects`와 `bb tm projects`, Workbench Agent registry와 `bb agents`, `wb doctor`와 `bb doctor`가
동시에 노출된다. 이것은 모두 제거할 중복이 아니다. `bb tm`은 terminal workspace 진입이고,
Workbench registry와 Dashboard는 정규화된 상태와 관찰 화면이다. `bb agents`는 Workbench observer가
직접 실행 작업까지 충분히 보여주기 전까지 terminal fallback으로 유지한다.

**방향:** 실행 UX와 상태 책임을 명령 이름이 아니라 소유권으로 구분한다. Workbench가 같은 도메인을
관찰하더라도 tmux·LazyVim·binbox의 독립 실행 경로를 자동으로 폐기하지 않는다.

### 2. tmux 관찰 이후 common session lifecycle은 별도 갭이다

Workbench는 이제 사용자가 직접 만든 tmux session/window/pane을 읽고 stable pane으로 복귀한다. managed
Agent/workflow와 알려진 AI CLI observed Task도 같은 화면에서 구분한다. 다만 이 구현은 tmux read-only
observer이며 cmux·Windows Terminal을 아우르는 공통 session registry나 lifecycle owner는 아니다.

**방향:** tmux가 실제 lifecycle owner라는 경계를 유지한다. non-AI observed classifier와 다른 backend의
session inventory는 실제 사용 근거와 신뢰 가능한 식별자가 생길 때 별도 확장한다.

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
| Dashboard Contexts read-only | 채택 | 상태 가독성은 높이되 평문·mutation 경계는 browser 밖에 유지 |

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
| 5 | 완료 | Environment와 local Secret | `wenv`·`sec` migration, project 연결, workflow 주입, read-only Context health와 평문 비노출 계약 |
| 6 | 다음 | fallback 정리와 배포 판정 | 관찰 증거가 있는 shim만 제거하고 physical cross-platform smoke를 별도 기록 |

Observed Task의 exit code를 알 수 없으면 성공·실패를 확정하지 않는다. Phase 4 이후에도 Dashboard에
arbitrary command runner를 만들지 않는다. Phase 5 완료는 CLI store·migration·선택적 subprocess 주입과
read-only Context health까지이며, kube mutation·expiry·Dashboard mutation은 포함하지 않는다.

## 실패 모드와 호환성 원칙

| 실패 모드 | 탐지 | 기본 동작 | 복구/롤백 |
|---|---|---|---|
| `wb` 없음 또는 schema mismatch | LazyVim error, Doctor | project만 명시적 fallback; 다른 state는 unavailable | 함께 호환되는 repo lock으로 복구 |
| legacy fallback이 primary 실패를 숨김 | compatibility latest source | fallback source와 오류를 노출 | primary 복구 후 대표 흐름 재실행 |
| stale cmux action | generator `--check` | 오래된 action 배포를 실패 처리 | `sync-workbench` 후 config rebuild |
| Agent backend reference drift | `Alive`/ownership 재검증 | jump/stop 거부 | task 상태 reconcile, terminal history 보존 |
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
| terminal UX 기준선 | `./tests/contract-test.sh --root-only` | 환경 유지보수자 | 모든 Phase 종료 | tmux `|,-,c,f,a`, LazyVim project key, 주요 `bb` entrypoint 유지 |
| Workbench core | `wb doctor --strict` | Workbench 유지보수자 | core/state 변경 후 | unavailable core 0 |
| Workbench optionality | static contract + Workbench 없는 shell smoke | 환경 유지보수자 | dependency 변경 후 | `bb tm`, `bb` toolbox, tmux/LazyVim 기본 경로 유지 |
| managed/observed 구분 | Workbench Task contract | Workbench 유지보수자 | Phase 2 이후 | provenance와 confidence를 잃지 않음 |
| cmux config drift | `generate-workbench.py --check`, config check | cmux-config 유지보수자 | project registry 변경·upgrade 후 | generated action 최신, reference 검사 성공 |
| Worktree 안전 | CLI/client contract test | Workbench·client 구현자 | mutation UI 변경 후 | dirty/locked/unmerged와 외부 worktree 거부 유지 |
| Windows/WSL 지원 | physical smoke 기록 | 환경 유지보수자 | Tier 1 지원 완료 판정 전 | bootstrap/doctor/editor/tmux/Agent/worktree 대표 흐름 성공 |
| Environment/Secret 비노출 | Workbench tests + browser Context 확인 | Workbench 유지보수자 | 관련 contract 변경 후 | argv/history/Dashboard JSON/browser에 평문 0건 |
| 현재 HEAD 통합 E2E | aggregate suite | 환경 유지보수자 | Phase 6 착수·release 판정 전 | `39100f2` Environment/Secret/workflow/Contexts suite 성공 |

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
| 8 | 현재 HEAD 통합 E2E 결과 확정 | 완료 | 환경 유지보수자 | `39100f2` aggregate 성공과 cleanup/git clean 기록 |
| 9 | fallback 정리와 배포 판정 | 다음 | 환경 유지보수자 | Phase 6 관찰 근거와 physical Linux/Windows/WSL/cmux smoke 확보 |

## 가정과 미확인 사항

- 이 제품은 현재 단일 사용자의 로컬 개발환경을 대상으로 한다.
- 사용 빈도와 release cadence의 정량 데이터는 아직 없다. 저장소 합병과 daemon 도입 근거로 사용하지 않는다.
- 현재 장비의 compatibility primary 관찰은 긍정적이지만 다른 장비의 사용을 증명하지 않는다.
- cmux config 구현과 tests는 존재하지만 현재 검증 장비에는 cmux executable이 없어 live backend 동작은 미확인이다.
- 물리 Linux/Windows/WSL smoke는 미확인이다. cross-build나 fixture 결과로 대체하지 않는다.
- 물리 cmux smoke도 미확인이다. browser fixture나 config test로 대체하지 않는다.

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
