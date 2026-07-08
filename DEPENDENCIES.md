# setup — 개인 환경 repo 오케스트레이션

`~/home/setup/` (원격: `dev-env-setup`) 은 여러 장비에서 **동일한 개인 환경**을 재현하는
오케스트레이션 레이어다. 실제 설정은 3개의 독립 GitHub repo(binbox·nvim·cmux-config)에 있고,
이 폴더의 스크립트가 그것들을 **의존 순서대로 clone·연결·셋업**하고 **점검**한다.

| 파일 | 역할 |
|---|---|
| `bootstrap.sh` | 프로비저닝 (쓰기). clone/pull → 심볼릭 링크 → 각 repo setup. **멱등**. |
| `upgrade.sh` | 최신 동기화 (쓰기). 각 repo 를 `sync_cmd` 로 최신화 (git pull + 플러그인 복원 등). |
| `doctor.sh` | 상태 점검 (읽기 전용). repo·링크·의존계약 검사, 아무것도 안 바꿈. |
| `repos.txt` | 매니페스트. 관리 대상 repo 목록 (한 줄 = 한 repo). |

하위 3개 repo는 `.gitignore` 로 제외된다(각자 독립 repo이므로). 이 레이어는 "어떤 repo를 어디에
연결하고 무엇으로 셋업하는가"만 관리한다.

---

## 구성 & 의존 그래프

```
        cmux-config          ← 오케스트레이션 (워크스페이스/패널에서 bb·nvim 실행)
        │        │
   (bb 명령)   (nvim 실행)
        ▼        ▼
     binbox      nvim
        ▲         ╎
        ╰┈┈┈┈┈┈┈┈┈╯  nvim → binbox 'tm' 포맷 참조 (약함)
```

- **binbox** (기반, repo: binbox) — `bb` 디스패처 툴킷. 의존 없음. `bb setup` 이 `~/.local/bin/bb`
  링크 + 셸 rc 등록.
- **nvim** (repo: lazyvim-config) — 에디터 설정. binbox 의 `tm`(tmux 레이아웃) 포맷을 느슨하게 참조.
- **cmux-config** (repo: cmux-config) — cmux 워크스페이스 정의. 패널에서 `bb <tool>` 과 `nvim` 을
  직접 호출 → **둘 다 필요**.

**설치 순서: binbox → nvim → cmux-config** (repos.txt 줄 순서 = 의존 순서).

---

## 빠른 사용법

```bash
cd ~/home/setup
./doctor.sh            # 상태 점검 (읽기 전용)
./bootstrap.sh         # 프로비저닝·셋업 — 새 장비/복구 (멱등)
./upgrade.sh           # 최신으로 동기화 — 평소 업데이트는 이거면 충분
```

| 명령 | 하는 일 |
|---|---|
| `./bootstrap.sh` | 전체: clone/pull → link → 각 repo setup |
| `./bootstrap.sh --no-pull` | 기존 repo pull 생략 (clone/link/setup 은 함) |
| `./bootstrap.sh --no-setup` | setup_cmd 생략 (clone/pull/link 만 — rc/설정 안 건드림) |
| `./bootstrap.sh --link-only` | 심볼릭 링크만 재생성 (경로 이동 후 복구 등, 안전) |
| `./bootstrap.sh binbox nvim` | 지정한 repo만 처리 |
| `./bootstrap.sh -h` | 도움말 |
| `./upgrade.sh` | 세 repo 를 의존 순서로 최신화 (binbox pull → nvim pull+plugin → cmux pull) |
| `./upgrade.sh binbox nvim` | 지정한 repo만 최신화 |
| `./upgrade.sh -h` | 도움말 |

> **bootstrap vs upgrade** — `bootstrap.sh` 는 *배치*(clone/link/setup, 새 장비·복구용, pull 은 부수효과),
> `upgrade.sh` 는 *최신 반영* 전용(각 repo 의 `sync_cmd`: git pull + nvim 플러그인 lock 복원 등).
> 평소 "업데이트 좀 당겨오자"는 `./upgrade.sh`.

---

## bootstrap.sh 동작 흐름

`repos.txt` 를 **줄 순서(=의존 순서)** 로 읽어, repo마다 아래 3단계를 수행한다:

```
repo 한 줄:  name | url | link_target | setup_cmd | sync_cmd
   │
   ├─ 1) clone / pull
   │     .git 없음  → git clone <url>                         (새 장비)
   │     .git 있음  → (--no-pull 아니면) 추적변경 없을 때만
   │                  git pull --ff-only                      (전진만)
   │
   ├─ 2) 심볼릭 링크  (link_target 있을 때)
   │     ln -sfn  ~/home/setup/<name>  <link_target>          (~ 확장, 매번 재생성)
   │
   └─ 3) 자체 setup   (setup_cmd 있고 --no-setup 아닐 때)
         ( cd <name> && eval "<setup_cmd>" )                  (repo 안에서 실행)
```

마지막에 `완료. 상태 점검: ./doctor.sh` 를 출력한다.

**pull 규칙**
- `--ff-only` — 절대 머지/충돌을 만들지 않고 전진만. 로컬이 앞서 있거나 갈라졌으면 그냥 skip.
- 클린 판정은 **추적 변경만** 본다(`git status --porcelain --untracked-files=no`). 그래서
  `.claude/`, `.DS_Store` 같은 untracked 파일은 pull 을 막지 않는다.
- 추적 변경이 있으면 그 repo만 "로컬 변경 있음" 경고 후 pull skip. 나머지는 계속 진행.

**setup 규칙**
- repo당 `setup_cmd` **한 줄만** 실행한다(아래 "자동 실행" 참고).
- 출력은 억제되고, 실패해도 경고만 남기고 **다음 repo로 계속**한다(전체가 멈추지 않음).
- 매 bootstrap 마다 실행되므로 setup_cmd 는 **멱등·경량**이어야 한다.

---

## 무엇이 "자동 실행"되나

bootstrap 은 repo 안의 모든 스크립트를 도는 게 아니라, **repos.txt 의 `setup_cmd` 한 줄만**
실행한다. 나머지 내부 스크립트는 전부 수동/온디맨드다.

| repo | bootstrap 자동 (setup_cmd) | upgrade (sync_cmd) | 수동 (온디맨드) |
|---|---|---|---|
| binbox | `./bb setup` (bb 링크 + 셸 rc 등록) | `./bb upgrade` (git pull) | 나머지 `bb <tool>` 들 — `tm`, `assume`, `kx`, `tfx`, `gx`, `dx`, `wenv`, `sec`, … |
| nvim | `./scripts/setup.sh --link --yes` (설정 링크) | `./scripts/setup.sh --sync --sync-plugins` (git pull + 플러그인 복원) | `--install`, `test-setup.sh` |
| cmux-config | `bash scripts/bootstrap.sh` (cmux 설정 링크) | `git pull --ff-only` | `build-config.py`, `check-config.sh`, `pull-local.sh` (역방향 캡처) |

**pull-local 은 upgrade 가 아니다** — `cmux-config/scripts/pull-local.sh` 는 라이브(`~/.config/cmux/*`,
ghostty)를 repo 로 **캡처(역방향, 커밋 준비용)** 한다. "최신으로 당겨오기"와 방향이 반대라 `upgrade.sh`
에 넣지 않는다. 라이브 변경을 저장할 때 별도로 수동 실행 → 그 뒤 git commit.

**nvim 뉘앙스** — `setup.sh` 는 한 스크립트가 여러 레이어를 담당한다. bootstrap 은 `--link` 만,
upgrade 는 `--sync --sync-plugins` 만 넘긴다:

| 기능 | 플래그 | 어디서 실행 |
|---|---|---|
| 설정 심볼릭 링크 (nvim/tmux/local.lua) | `--link` | ✅ bootstrap |
| git 동기화 | `--sync` | ✅ upgrade |
| 플러그인 버전 맞춤 (Lazy 복원) | `--sync-plugins` | ✅ upgrade (nvim 필요) |
| 툴 설치 (brew/asdf/npm/go) | `--install` | ❌ 새 장비 1회성 (아래) |

→ 링크/rc 등록은 **bootstrap**, git pull·플러그인 복원은 **upgrade**, **무거운 툴 설치는 새 장비 1회성 수동**.

---

## 새 장비 세팅

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup   # 진입점만 먼저
cd ~/home/setup && ./bootstrap.sh          # 나머지 3개 clone + 연결 + 경량 셋업
exec $SHELL -l                             # 셸 rc 재적용
```

**툴 설치는 1회성** — 무거운 패키지/런타임(neovim, ripgrep, asdf 툴 등)은 bootstrap 자동 실행에서
제외돼 있다(멱등하지 않고 asdf 미설치 시 실패). 새 장비에서 한 번만:

```bash
cd ~/home/setup/nvim && ./scripts/setup.sh --install --link --with-font --with-tmux-plugins --yes
```

이후 평소 업데이트는 `cd ~/home/setup && ./upgrade.sh` 한 줄이면 세 repo 가 최신으로 맞춰진다
(git pull + nvim 플러그인 lock 복원 포함).

---

## 계약 (바꿀 때 같이 고쳐야 하는 것)

| 바뀌는 곳 | 영향 받는 곳 | 확인할 파일 |
|---|---|---|
| binbox `libexec/<tool>` 이름 변경/삭제 | cmux 가 부르는 `bb <tool>` | `cmux-config/config.d/commands/*.json`, `actions/*.json` |
| binbox `tm` 레이아웃 포맷 변경 | nvim 파싱 | `nvim/lua/plugins/editor.lua` |
| 배포 경로(`~/binbox`, `~/.config/nvim`) 변경 | cmux `cwd`, 각종 참조 | `repos.txt`, cmux `commands/tools.json` |

→ `./doctor.sh` 가 `bb <tool>` ↔ `binbox/libexec` 대조로 계약 깨짐을 자동 감지한다.

---

## repo 추가/변경

`repos.txt` 에 한 줄 추가: `name | git_url | link_target | setup_cmd | sync_cmd`

- 줄 위치 = 설치 순서. 의존이 있으면 의존 대상보다 **아래**에.
- `link_target` 없으면 비움 (심볼릭 링크 안 만듦). `~` 확장됨.
- `setup_cmd` 없으면 비움. 넣을 땐 **멱등·경량**만 (무거운 설치는 새 장비 1회성 단계로 분리).
- `sync_cmd` 없으면 비움. "최신으로 동기화" 명령 (git pull 등) — `./upgrade.sh` 가 이 컬럼을 실행한다.
- 편집 후 `./bootstrap.sh`(프로비저닝) 또는 `./upgrade.sh`(동기화) 재실행하면 반영됨.

---

## 배포 링크 (현재 장비)

| repo | 물리 위치 | 런타임 링크 |
|---|---|---|
| binbox | `~/home/setup/binbox` | `~/binbox`, `~/.local/bin/bb` |
| nvim | `~/home/setup/nvim` | `~/.config/nvim`, `~/.tmux.conf` |
| cmux-config | `~/home/setup/cmux-config` | `~/.config/cmux/*`, `~/Library/Application Support/com.cmuxterm.app/*` |
