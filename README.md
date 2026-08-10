# dev-env-setup

여러 장비에서 **개인 환경과 업무 흐름을 재현하고 이어가는 local-first 운영 기반**.

이 환경의 제품 방향은 **terminal-first 개인 운영 환경**이다. 개발 작업을 출발점으로 문서, 계획,
정보 수집, 반복 업무, 자동화와 외부 서비스 연동을 한 흐름에서 연결하되 원본 도구와 데이터의 소유권은
보존한다. tmux와 LazyVim이 계속 주 작업 공간을 맡고, binbox(`bb`)는 운영 toolbox로 유지한다.
Workbench Core는 프로젝트·작업·실행 상태와 관찰 결과를 정규화하고, Dashboard는 현황과 복귀 지점을
보여주는 보조 operations console이다. Workbench가 없거나 Dashboard를 열지 않아도 tmux·LazyVim·`bb`의
기본 흐름은 계속 동작해야 한다.

장기 제품 비전은 개발환경 재현을 기반으로 개인 업무와 개발을 연결하는 나만의 통합 도구다. MCP,
직접 API, webhook, 파일과 Git은 교체 가능한 연동 방식이며 어느 하나도 제품의 필수 기반으로 두지 않는다.
Agent 관리와 multi-agent orchestration은 Orca 같은 외부 backend 연동을 먼저 검증하고, 공통 상태·정책이
반복적으로 필요할 때만 제한된 자체 기능을 검토한다. 이 장기 영역들은 현재 구현 기능이 아니다.

제품 기획의 첫 지원 기준은 WSL primary Tier-1과 macOS 병행 검증이다. 일반 설치는 Workbench를 포함한
`workbench` profile을 기본으로 하고, 최소 설치·복구에는 명시적 `terminal` profile을 둔다. 사용자 작성
정보는 Markdown을 원본으로, SQLite는 재구축 가능한 검색·실행 index로 사용한다. 외부 연동은 GitHub와
Slack의 read-only 흐름부터 시작하며, 여러 장비 보존은 private GitHub history와 암호화된 OneDrive
backup을 역할별로 분리하는 방향이다. 세부 내용은 [제품 기획서](plan/PRODUCT-PLAN.md)를 따른다.

통합 Workbench의 목표 workspace는 WSL과 macOS 모두 Orca 하나다. Windows Terminal, iTerm2와 cmux를
Workbench의 신규 backend나 제품 진입점으로 확장하지 않는다. 저장소에 남아 있는 기존 adapter는 현재
구현 이력이며, Orca 전환 검증 후 별도 deprecation 단계에서 안전하게 정리한다.

실제 구현은 4개의 독립 GitHub repo(**binbox · nvim · cmux-config · workbench**)에 있고, 이 폴더의 작은
스크립트 3개가 그것들을 **의존 순서대로 clone·연결·셋업**하고 **점검·동기화**한다. 새 장비에서
`git clone` 한 줄로 시작한다. macOS와 Windows/WSL 모두 `./bootstrap.sh`를 사용하며 platform profile이
cmux의 optional/disabled 상태를 자동 계산한다.

```
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup && ./bootstrap.sh && exec $SHELL -l
```

> 이 repo는 "어떤 repo를 어디에 연결하고 무엇으로 셋업하는가"만 관리한다. 실제 도구/설정
> 내용은 각 하위 repo에 있고, 여기선 `.gitignore` 로 제외된다(각자 독립 repo이므로).

---

## 구성

```text
tmux + LazyVim        주 작업 공간: 분할·탐색·편집·실행
       │
       ├── binbox     toolbox: tmux/Git/AWS/Kubernetes/Terraform/보안 명령
       │
       └── Workbench Core      observer/state: project·Task·health 정규화
                    └── Dashboard      ops console: 현황·이상·복귀·제한된 제어

cmux-config           macOS에서 위 구성요소를 여는 선택적 client/backend
dev-env-setup         설치·업데이트·호환 snapshot·통합 검증
```

| repo | 원격 | 하는 일 | 배포 링크 |
|---|---|---|---|
| **binbox** | `binbox` | `bb` CLI 툴킷 (tmux/git/k8s/aws/terraform/docker/secret). 기반 레이어. | `~/binbox`, `~/.local/bin/bb` |
| **nvim** | `lazyvim-config` | DevOps용 LazyVim 설정 (+ tmux 설정). | `~/.config/nvim`, `~/.tmux.conf` |
| **cmux-config** | `cmux-config` | cmux 워크스페이스 정의. 패널에서 `bb`·`nvim` 을 직접 호출 → 둘 다 필요. | `~/.config/cmux/*` |
| **workbench** | `workbench` | 선택적 `wb` observer/state core, backend adapters, localhost 운영 Dashboard와 내장 Guide. | `~/.local/bin/wb` |

**설치 순서: binbox → nvim → cmux-config → workbench** (`repos.txt` 줄 순서 = 의존 순서).

---

## 파일

| 파일 | 역할 |
|---|---|
| `bootstrap.sh` | **프로비저닝**(쓰기). clone/pull → 심볼릭 링크 → 각 repo setup. 멱등. |
| `upgrade.sh` | **최신 동기화**(쓰기). 각 repo 를 `sync_cmd` 로 최신화 (git pull + nvim 플러그인 복원 등). |
| `doctor.sh` | **상태 점검**(읽기 전용). repo·링크·의존계약 검사. 아무것도 안 바꿈. |
| `repos.txt` | **매니페스트**. 관리 대상 repo 목록 (한 줄 = 한 repo). |
| `platforms/*.repos` | platform별 required/optional/disabled 선택과 severity. |
| `locks/repos.lock` | 검증된 child repo commit snapshot. mismatch는 report-only. |
| `tests/contract-test.sh` | root/child aggregate contract test entrypoint. |
| `DEPENDENCIES.md` | 상세 레퍼런스 (동작 흐름, 자동 실행 범위, 계약, repo 추가 방법). |
| `plan/` | 프로젝트·세션·AI Agent 환경의 self-contained 통합 계획 패키지. |
| `WORKBENCH-PLAN.md` | 기존 링크를 `plan/README.md`로 안내하는 호환용 진입점. |

---

## 빠른 시작

### 새 macOS 장비

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup   # 진입점만 먼저
cd ~/home/setup && ./bootstrap.sh          # 나머지 4개 clone + 연결 + 경량 셋업
exec $SHELL -l                             # 셸 rc 재적용
```

Windows Terminal + WSL2에서는 platform selector가 cmux를 자동으로 disabled 처리한다.

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup
./bootstrap.sh
./doctor.sh
```

Workbench build에는 Go 1.25.12가 prerequisite다. bootstrap은 Go 자체를 설치하지 않으며, 없으면
workbench setup을 required failure로 보고한다. neovim, ripgrep, asdf 툴 같은 무거운 툴 설치도
bootstrap 자동 실행에서 **제외**돼 있다.
새 장비에서 한 번만:

```bash
cd ~/home/setup/nvim && ./scripts/setup.sh --install --link --with-font --with-tmux-plugins --yes
```

### 평소

```bash
cd ~/home/setup
./doctor.sh            # 상태 점검 (읽기 전용)
./upgrade.sh           # 네 repo 를 최신으로 동기화 — 평소 업데이트는 이거면 충분
```

---

## 자주 쓰는 명령

| 명령 | 하는 일 |
|---|---|
| `./bootstrap.sh` | 전체: clone/pull → link → 각 repo setup |
| `./bootstrap.sh --no-pull` | 기존 repo pull 생략 (clone/link/setup 은 함) |
| `./bootstrap.sh --no-setup` | setup_cmd 생략 (clone/pull/link 만) |
| `./bootstrap.sh --link-only` | 심볼릭 링크만 재생성 (경로 이동 후 복구용, 안전) |
| `./bootstrap.sh binbox nvim` | 지정한 repo만 처리 |
| `./bootstrap.sh --show-selection` | 현재 platform과 repo severity/선택 결과만 표시(쓰기 없음) |
| `./bootstrap.sh --platform linux --show-selection` | CI/검증용 platform 선택 결과 표시 |
| `./bootstrap.sh --with cmux-config` | optional/disabled repo를 명시적으로 required 실행 |
| `./bootstrap.sh --without cmux-config` | optional repo 제외(required 제외는 오류) |
| `./upgrade.sh` | 네 repo 를 의존 순서로 최신화 |
| `./upgrade.sh binbox` | 지정한 repo만 최신화 |
| `./doctor.sh` | repo/링크/의존계약 점검 (문제 있으면 종료코드 ≠ 0) |

> **bootstrap vs upgrade** — `bootstrap.sh` 는 *배치*(clone/link/setup, 새 장비·복구용,
> pull 은 부수효과), `upgrade.sh` 는 *최신 반영* 전용(각 repo 의 `sync_cmd`). 평소
> "업데이트 좀 당겨오자"는 `./upgrade.sh`.

---

## 더 읽기

- **[plan/README.md](plan/README.md)** — 현재 사실을 모은 `raw/`, 이전 계획 `archive/`, 공동 작성 중인 새 제품 기획서의 진입점.
- **[DEPENDENCIES.md](DEPENDENCIES.md)** — 동작 흐름, 무엇이 자동 실행되나, 계약(변경 시 같이
  고칠 것), repo 추가/변경 방법. 이 repo 를 손볼 때 먼저 읽는다.
- **[binbox README](https://github.com/jisung9870/binbox/blob/main/README.md)** — `bb` 도구 전체 목록과 사용법.
- **[lazyvim-config README](https://github.com/jisung9870/lazyvim-config/blob/main/README.md)** — LazyVim 설정 구조, 멀티 머신 동기화, 초기 설정.
- **[cmux-config README](https://github.com/jisung9870/cmux-config/blob/main/README.md)** — cmux 워크스페이스/작업판 관리.
