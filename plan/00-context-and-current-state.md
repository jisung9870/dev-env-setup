# 배경과 현재 상태

## 문서 목적

이 문서는 이전 대화를 모르는 독자가 현재 환경, 네 저장소의 책임, 실제 결합 지점, 확인된 위험과
분석 한계를 복원할 수 있게 한다. 여기의 **사실**과 이후 문서의 **권고**를 구분한다.

## 사용자 환경과 목표

현재 기본 작업 환경:

- macOS에서 cmux를 주요 desktop workbench로 사용
- tmux를 지속 가능한 session과 SSH/장시간 작업에 사용
- LazyVim을 사람이 직접 읽고 수정하는 기준 editor로 사용
- Codex와 Claude Code를 coding/review Agent로 사용
- `binbox`의 `bb` 명령으로 tmux, Kubernetes, Terraform, AWS 등 반복 작업 수행
- 개인 학습과 개인 개발도 같은 환경으로 통합하려는 목표

목표는 editor를 교체하는 것이 아니라, 프로젝트·세션·Agent·worktree 상태와 실행 진입점을 통합하는
것이다. 다른 장비에서도 같은 명령과 데이터 모델로 작업을 재현해야 한다.

## 분석 대상과 기준 commit

2026-08-04에 다음 public GitHub repo를 읽기 전용으로 분석했다.

| repo | 분석 기준 commit | 현재 책임 |
|---|---|---|
| `jisung9870/dev-env-setup` | `e897a7209625a59a2d1ea4206c8f6be21f877c3b` | 여러 repo의 clone, setup, update, doctor 순서 |
| `jisung9870/binbox` | `00b4f61433a8d095db919df303dbdfc5b0d35d5c` | `bb` dispatcher와 실행 도구 |
| `jisung9870/cmux-config` | `c8ce2688c625ea7a6b5d9d44e43f9b72554603bb` | cmux workspace/action/notification/browser 설정 |
| `jisung9870/lazyvim-config` | `426093864a32e23a095ebd1418b3425ff378d3cb` | Neovim 설정, tmux 설정, tool/runtime setup |

작업을 재개할 때 commit이 달라졌다면 아래 결합 계약이 그대로인지 먼저 재검증한다.

## 저장소별 확인된 책임

### `dev-env-setup`

**사실:** `repos.txt`의 행 순서가 설치·update 의존 순서다. 현재 순서는
`binbox → nvim → cmux-config`다.

**사실:** `bootstrap.sh`는 repo마다 clone/pull → runtime link → child `setup_cmd`를 실행한다.
`upgrade.sh`는 각 `sync_cmd`를 같은 순서로 실행한다.

**사실:** `doctor.sh`는 repo/link 상태와 cmux가 참조하는 `bb <tool>` 존재 여부를 확인하지만,
LazyVim의 sessionizer 계약, cmux action reference, 호환 commit 조합까지 검증하지 않는다.

### `binbox`

**사실:** `bb`는 BusyBox 방식 dispatcher다. 실행 가능한 `libexec/<tool>`을 자동 발견한다.

**사실:** 주요 확장점은 다음과 같다.

- `libexec/<tool>`: 새 `bb` subcommand
- `dx.d/<tool>`: containerized development preset
- `tmux-layouts/*-layout`: tmux layout
- `$XDG_CONFIG_HOME/binbox/wenv.d`: environment preset
- zsh completion과 alias

**사실:** `bb tm`은 `~/.config/tmux-sessionizer/dirs`를 project registry처럼 사용한다. `=` prefix는
해당 경로 자체를 project 후보로 취급한다.

**사실:** `bb agents`는 tmux pane의 command와 화면 문자열을 정규식으로 읽어 Codex/Claude 상태를
running/waiting/idle로 분류한다.

### `cmux-config`

**사실:** 사람이 수정하는 source는 `config.d/**/*.json`이며 `cmux.json`은 committed generated
output이다.

**사실:** cmux action에는 Codex, Claude, `bb doctor`, project/workflow workspace가 포함된다.

**사실:** `~/binbox`, `~/.config/nvim`, `~/home/projects` 같은 경로와 `bb tfx`, `bb kx` 명령을
직접 참조한다.

**사실:** cmux는 native tab에서 Agent를 시작할 수 있지만, 이것은 tmux pane 기반 `bb agents`의
관찰 범위와 일치하지 않는다.

### `lazyvim-config`

**사실:** LazyVim plugin 설정 외에 다음도 관리한다.

- macOS/WSL setup
- Neovim과 language tool/runtime 설치
- `~/.tmux.conf`와 TPM plugin lifecycle
- project picker
- ToggleTerm과 tmux navigation

**사실:** LazyVim project picker는 `~/.config/tmux-sessionizer/dirs`와 `=` prefix를 binbox와 별도로
파싱한다.

**사실:** Neovim과 tmux 양쪽에서 `bb tm`을 실행하고, tmux popup에서 `bb agents`를 실행한다.

## 현재 bootstrap 흐름

```text
git clone dev-env-setup ~/home/setup
        │
        ▼
./bootstrap.sh
        │
        ├─ clone/pull binbox      → ~/binbox, ~/.local/bin/bb, shell rc
        ├─ clone/pull nvim        → ~/.config/nvim, ~/.tmux.conf
        └─ clone/pull cmux-config → ~/.config/cmux/*, Application Support files
        │
        ▼
새 장비에서 nvim setup --install을 별도 실행
        │
        ▼
./doctor.sh
```

무거운 tool/runtime install은 bootstrap에서 제외되어 있어 새 장비 재현은 현재 두 단계다.

## 중복과 결합

| 계약/상태 | producer | consumer | 현재 문제 |
|---|---|---|---|
| project roots | sessionizer file, cmux config | binbox, LazyVim, cmux | 세 목록이 drift할 수 있음 |
| `bb` command 이름 | binbox | cmux, tmux, LazyVim | rename 시 여러 repo 동시 변경 |
| session/layout | binbox/tmux, cmux, ToggleTerm | 사용자 | pane 생성 책임이 중복 |
| Agent state | tmux 화면, cmux native session | `bb agents`, cmux UI | 통합 task ID와 registry 없음 |
| runtime link | parent bootstrap, child setup | shell/editor/cmux | link owner가 중복 |
| repo version | 각 repo current branch | 전체 환경 | compatible commit set 없음 |

## 위험 순위

| 순위 | 위험 | 가능성 | 영향 | 탐지 | 되돌리기 |
|---|---|---|---|---|---|
| 1 | project/Agent/command 복수 source of truth | 높음 | 높음 | 어려움 | 중간 |
| 2 | 순차 update 중 repo 계약 불일치 | 중간 | 높음 | 중간 | 중간 |
| 3 | cmux/tmux/Neovim 오케스트레이션 중복 | 높음 | 중간 | 쉬움 | 쉬움 |
| 4 | Agent 화면 문자열 scraping 오판 | 높음 | 중간 | 어려움 | 쉬움 |
| 5 | parent/child link owner 중복 | 중간 | 중간 | 중간 | 중간 |
| 6 | 하드코딩 경로와 command | 중간 | 중간 | 쉬움 | 쉬움 |

## 분석 당시 검증 결과

- `binbox`: Bats 263개 통과
- `cmux-config`: generated config check와 JSON parse 통과
- `dev-env-setup`: `bootstrap.sh`, `upgrade.sh`, `doctor.sh` Bash syntax 통과
- `lazyvim-config`: setup/doctor 관련 Bash syntax 통과

## 미확인 범위

다음은 repository evidence만으로 확인하지 못했다. 새 장비 또는 새 세션에서 사실로 가정하지 않는다.

- 실제 설치 장비의 symlink target과 local override
- 실행 중인 cmux/tmux session과 socket 상태
- private project별 `.cmux/cmux.json`
- 다른 장비의 macOS/WSL package 상태
- 기준 commit 이후 upstream cmux/Codex/Claude UI 변경

이 미확인 범위는 목표 아키텍처를 뒤집지는 않지만, 구현 전 doctor와 smoke test 범위를 결정한다.
