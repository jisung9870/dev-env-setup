# Personal Workbench 통합 계획

- 상태: **권고안, 구현 전**
- 기준일: 2026-08-04
- 목적: 장비가 바뀌어도 현재 개발 환경 분석과 통합 작업을 같은 기준에서 재개한다.
- 범위: `dev-env-setup`, `binbox`, `lazyvim-config`, `cmux-config`와 향후 `workbench` control plane

## 권고 결론

현재 네 저장소를 하나로 합치지 않는다. 대신 프로젝트·세션·Agent·worktree 상태를 관리하는
headless `workbench` CLI를 추가하고, cmux와 LazyVim을 그 CLI의 얇은 UI client로 연결한다.

```text
dev-env-setup      장비 provisioning, repo 호환 버전, 통합 doctor
       │
       ▼
workbench          프로젝트·세션·Agent·worktree의 source of truth
  ├─ cmux adapter  desktop workspace와 알림
  ├─ nvim client   picker·상태·작업 실행 UI
  ├─ tmux adapter  장시간 세션·SSH·재접속
  └─ binbox        Kubernetes·Terraform·AWS 등 실제 실행 provider
```

별도 desktop/web 앱은 첫 단계에 만들지 않는다. 구조화 API와 두 client가 안정된 뒤, 여러 Agent와
worktree를 동시에 시각화할 필요가 실제로 확인될 때 추가한다.

## 현재 확인된 상태

분석 기준 commit은 다음과 같다. 이후 변경을 검토할 때 이 표를 출발점으로 사용한다.

| repo | 기준 commit | 현재 책임 | 판단 |
|---|---|---|---|
| `dev-env-setup` | `8601df02fcafab51d4a5eee049e9caddccd8a2a6` | clone/link/setup/update/doctor 순서 | 유지하되 provisioning 전용으로 좁힌다. |
| `binbox` | `00b4f61433a8d095db919df303dbdfc5b0d35d5c` | `bb` dispatcher와 실행 도구 | headless execution provider로 유지한다. |
| `cmux-config` | `c8ce2688c625ea7a6b5d9d44e43f9b72554603bb` | workspace/action/notification/browser | workbench의 desktop client로 유지한다. |
| `lazyvim-config` | `426093864a32e23a095ebd1418b3425ff378d3cb` | Neovim, tmux 설정, tool/runtime setup | 편집기 client와 설정에 집중하도록 점진적으로 좁힌다. |

검증된 사실:

- 설치 순서는 `repos.txt`의 `binbox → nvim → cmux-config`다.
- `binbox`의 `libexec/<tool>`은 `bb <tool>`로 자동 발견된다.
- `cmux-config/config.d`가 source이고 `cmux.json`은 generated output이다.
- LazyVim과 binbox는 `~/.config/tmux-sessionizer/dirs`와 `=` prefix 형식을 각각 파싱한다.
- cmux는 Codex/Claude를 native tab에서 실행하지만 `bb agents`는 tmux pane만 관찰한다.
- `dev-env-setup`과 각 child setup이 일부 runtime link를 중복 관리한다.

## 해결할 핵심 문제

### 1. 프로젝트 목록의 복수 source of truth

프로젝트 경로가 binbox sessionizer 파일, LazyVim parser, cmux workspace group에 각각 표현된다.
한 곳을 수정해도 다른 UI에 자동 반영되지 않는다.

**권고:** 최종적으로 `workbench projects list --json`을 유일한 조회 계약으로 사용한다. 기존
sessionizer 파일은 migration 기간의 입력 또는 generated compatibility file로만 유지한다.

### 2. 오케스트레이션 중복

cmux workspace, tmux layout, Neovim ToggleTerm이 모두 pane/terminal을 생성할 수 있다.

**권고:** `workbench open`이 실행 backend를 선택한다.

- 로컬 일반 작업: cmux native workspace
- 장시간 작업, SSH, 재접속: tmux
- Neovim terminal: 현재 편집 작업의 보조 명령만 담당
- 하나의 작업을 cmux와 tmux가 동시에 layout하지 않는다.

### 3. Agent 상태 단절

`bb agents`는 tmux 화면 문자열을 정규식으로 분류하므로 cmux native Agent를 보지 못하고 upstream
문구 변경에도 취약하다.

**권고:** Agent를 시작할 때 `task_id`, `project_id`, `agent_kind`, `backend`, `state`를 workbench
state에 기록한다. tmux에서는 `@workbench_task` 같은 pane metadata를 함께 설정하고, 화면 scraping은
미등록 legacy pane을 위한 fallback으로만 남긴다.

### 4. 호환 버전과 부분 실패

현재 repo들은 현재 branch를 순차 update하며 함께 검증된 commit 조합을 기록하지 않는다. setup
실패도 경고 후 계속 진행될 수 있다.

**권고:** `dev-env-setup`이 compatible repo snapshot과 통합 contract test를 소유한다. bootstrap은
preflight → apply → doctor 순서로 실행하며 부분 실패 시 non-zero로 끝난다.

## 목표 인터페이스

명령 이름은 구현 중 바꿀 수 있지만 JSON 필드와 exit code는 versioned contract로 관리한다.

```bash
wb projects list --json
wb project show <project-id> --json
wb open <project-id> [--backend cmux|tmux|shell]
wb worktree create <project-id> <branch>
wb agents start <project-id> --agent codex|claude
wb agents list --json
wb doctor [--profile personal|work] --json
```

최소 공통 응답 envelope:

```json
{
  "schema_version": 1,
  "ok": true,
  "data": {},
  "warnings": [],
  "error": null
}
```

실패 시 사람이 읽는 메시지는 stderr, 구조화 결과는 stdout에 출력한다. 자동화가 성공/부분 성공/
실패를 구분할 수 있도록 exit code 계약을 문서화한다.

## 저장소별 목표 책임

### `dev-env-setup`

- repo manifest와 설치 순서
- `personal`, `work`, `minimal` machine profile
- 함께 검증된 repo commit snapshot
- preflight/apply/doctor와 통합 contract test
- child installer 호출만 담당하고 child가 소유한 runtime link를 직접 다시 만들지 않는다.

현재 `repos.txt`의 pipe 문자열과 `eval`은 바로 control-plane API로 확장하지 않는다. 구조화 manifest로
옮길 때 schema validation과 명시적 command 배열을 사용한다.

### `binbox`

- Kubernetes, Terraform, AWS, tmux helper 등 실제 명령 실행
- stable JSON provider command
- 사용자 확장 도구와 completion 생성
- 프로젝트·Agent의 authoritative state는 소유하지 않는다.

우선 추가할 compatibility API:

```bash
bb tm projects --json
bb tm sessions --json
bb agents --json
bb doctor --json
```

### `cmux-config`

- 사람이 관리하는 global base 설정
- workbench project/workflow에서 생성되는 action/command fragment
- Agent notification과 browser UX
- generated config drift, command reference, sensitive data CI

repo별 특수 layout은 각 프로젝트의 `.cmux/cmux.json`에 둔다. 전역 설정에 모든 프로젝트별 규칙을
모으지 않는다.

### `lazyvim-config`

- Neovim 편집 경험, language/plugin 설정, help 문서
- `wb ... --json`을 소비하는 Snacks picker와 상태 UI
- machine-local Neovim override

tmux 설정은 당장 새 repo로 분리하지 않는다. Neovim과 독립적으로 변경·배포할 필요가 반복될 때만
`tmux-config` 분리를 재검토한다.

### 신규 `workbench`

- project registry
- cmux/tmux/shell backend 선택
- Git worktree lifecycle
- Agent launch registry와 상태
- versioned JSON schema
- cmux, tmux, binbox adapter

초기에는 daemon 없는 단일 CLI로 구현한다. 실시간 상태 event가 필요해질 때만 local socket 또는
background service를 추가한다.

## 구현 단계

### Phase 0 — 기존 계약 고정

작업:

- `bb` command, sessionizer 형식, cmux command/action reference를 contract test로 고정
- compatible repo commit을 기록하는 lock/snapshot 추가
- bootstrap/update의 부분 실패를 non-zero로 반환
- 각 runtime link의 owner를 하나로 정리
- cmux generated config와 sensitive scan을 CI에서 검증

수용 기준:

- 존재하지 않는 `bb <tool>`을 cmux가 참조하면 검사 실패
- cmux action의 `commandName` 대상이 없으면 검사 실패
- child setup 하나가 실패하면 전체 bootstrap이 성공으로 보고되지 않음
- lock에 기록된 네 repo commit과 현재 checkout 차이를 doctor가 표시

롤백:

- 기존 `repos.txt`, setup command, runtime link 동작을 유지하는 compatibility mode를 제공한다.
- lock 적용 실패 시 자동 checkout하지 않고 차이만 보고한다.

### Phase 1 — 구조화 read API

작업:

- binbox에 project/session/agent/doctor JSON 출력 추가
- LazyVim project picker가 JSON API를 우선 사용
- 기존 file parser를 fallback으로 유지

수용 기준:

- 같은 장비에서 `bb tm projects --json`과 LazyVim picker의 project ID/path 집합이 같음
- JSON schema fixture가 macOS와 Linux CI에서 통과
- CLI가 없거나 구버전이면 LazyVim이 오류를 설명하고 기존 parser로 fallback

롤백:

- LazyVim의 API 사용 flag를 끄면 즉시 기존 parser로 돌아감

### Phase 2 — `workbench` core

작업:

- project registry와 profile overlay
- `open`, worktree, Agent launch/list
- cmux/tmux/shell adapter
- state migration과 backup

수용 기준:

- `wb open <id>`가 선택한 backend에 같은 project root를 전달
- 같은 branch의 worktree 중복 생성을 차단
- Agent launch가 stable task ID를 반환하고 `wb agents list --json`에 나타남
- 손상된 state file은 원본을 보존하고 명확한 오류로 종료

롤백:

- workbench state를 timestamp backup한 뒤 migration
- 기존 `bb tm`과 cmux command는 migration 기간 동안 계속 사용 가능

### Phase 3 — cmux와 LazyVim client

작업:

- workbench manifest에서 cmux command fragment 생성
- LazyVim에 project, Agent, worktree picker 추가
- cmux/tmux에서 동일한 task/project ID 표시

수용 기준:

- 프로젝트 한 번 등록으로 cmux와 LazyVim 양쪽에 나타남
- cmux와 tmux에서 시작한 Agent가 같은 `wb agents list`에 표시
- UI가 shell 문자열을 직접 조립하지 않고 versioned CLI contract만 사용

### Phase 4 — 책임 정리

작업:

- 중복 project root와 command registry 제거
- `lazyvim-config`의 OS/runtime 설치 범위를 `dev-env-setup` profile로 점진 이전
- 경로 하드코딩을 profile/manifest로 이전
- 오래된 screen scraping과 compatibility parser 제거 조건 점검

제거 조건:

- 지원하는 모든 장비가 새 schema와 CLI를 사용
- fallback 사용 여부를 doctor에서 확인할 수 있음
- 한 번의 release cycle 동안 legacy fallback 호출이 없음

### Phase 5 — 별도 Front UI 결정

다음 조건 중 하나가 반복될 때만 `workbench-ui`를 검토한다.

- 동시에 운영하는 Agent/worktree가 많아 cmux와 picker만으로 상태 파악이 어려움
- diff, test, browser, 승인 대기를 한 화면에서 비교해야 함
- Neovim을 열지 않고 장시간 Agent를 관찰해야 함

UI는 shell command를 직접 실행하지 않고 workbench의 local API만 호출해야 한다. 인증 없는 network
listen, arbitrary command 입력, secret 원문 노출은 허용하지 않는다.

## 보안·운영 체크리스트

- committed manifest와 generated config에 password/token/secret을 넣지 않는다.
- local state와 socket은 현재 사용자만 읽고 쓸 수 있게 한다.
- UI가 임의 shell 문자열을 저장·실행하지 않게 command ID와 argument schema를 사용한다.
- Terraform apply/destroy 같은 변경 명령의 기존 확인 절차를 adapter에서도 보존한다.
- setup, state migration, generated config 변경 전 복구 가능한 backup을 만든다.
- doctor는 필수 capability와 선택 capability를 구분한다.
- macOS와 WSL에서 path, shell, symlink 동작을 각각 검증한다.

2차 영향:

- 중앙 state가 손상되면 여러 UI가 동시에 영향을 받으므로 atomic write와 backup이 필요하다.
- CLI schema 변경은 cmux와 LazyVim을 동시에 깨뜨릴 수 있으므로 schema version과 compatibility 기간이
  필요하다.
- desktop/web UI가 추가되면 현재 trusted local shell 경계가 넓어지므로 network와 secret 경계를 별도로
  설계해야 한다.

## 다른 장비에서 작업 재개

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup
./bootstrap.sh
./doctor.sh
```

이미 설치된 장비에서는:

```bash
cd ~/home/setup
git pull --ff-only
./doctor.sh
```

그다음 이 문서에서 가장 앞의 미완료 Phase부터 진행한다. 구현 전에는 다음을 확인한다.

1. 네 repo가 clean한가.
2. 분석 기준 commit 이후 관련 계약이 바뀌었는가.
3. 기존 tests와 generated config check가 통과하는가.
4. 변경할 계약의 producer와 모든 consumer를 찾았는가.
5. rollback 또는 compatibility fallback이 준비됐는가.

## 현재 검증 기록

2026-08-04 분석 시점:

- `binbox`: Bats 263개 통과
- `cmux-config`: `scripts/build-config.py --check`와 JSON parse 통과
- `dev-env-setup`: `bootstrap.sh`, `upgrade.sh`, `doctor.sh` Bash syntax 통과
- `lazyvim-config`: setup/doctor 공통 스크립트 Bash syntax 통과

실제 설치된 장비의 symlink, machine-local override, 실행 중인 cmux/tmux session은 이 기록에 포함되지
않는다. 작업을 재개한 장비에서 `./doctor.sh`와 각 child repo doctor를 다시 실행한다.
