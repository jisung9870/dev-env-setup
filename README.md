# dev-env-setup

여러 장비에서 **동일한 개인 개발 환경**을 재현하는 오케스트레이션 레이어.

실제 설정은 3개의 독립 GitHub repo(**binbox · nvim · cmux-config**)에 있고, 이 폴더의 작은
스크립트 3개가 그것들을 **의존 순서대로 clone·연결·셋업**하고 **점검·동기화**한다. 새 장비에서
`git clone` 한 줄로 시작해 `./bootstrap.sh` 하나면 나머지가 제자리에 붙는다.

```
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup
cd ~/home/setup && ./bootstrap.sh && exec $SHELL -l
```

> 이 repo는 "어떤 repo를 어디에 연결하고 무엇으로 셋업하는가"만 관리한다. 실제 도구/설정
> 내용은 각 하위 repo에 있고, 여기선 `.gitignore` 로 제외된다(각자 독립 repo이므로).

---

## 구성

```
        cmux-config          ← 오케스트레이션 (워크스페이스/패널에서 bb·nvim 실행)
        │        │
   (bb 명령)   (nvim 실행)
        ▼        ▼
     binbox      nvim         ← nvim 은 binbox 'tm' 레이아웃 포맷을 느슨히 참조
```

| repo | 원격 | 하는 일 | 배포 링크 |
|---|---|---|---|
| **binbox** | `binbox` | `bb` CLI 툴킷 (tmux/git/k8s/aws/terraform/docker/secret). 기반 레이어. | `~/binbox`, `~/.local/bin/bb` |
| **nvim** | `lazyvim-config` | DevOps용 LazyVim 설정 (+ tmux 설정). | `~/.config/nvim`, `~/.tmux.conf` |
| **cmux-config** | `cmux-config` | cmux 워크스페이스 정의. 패널에서 `bb`·`nvim` 을 직접 호출 → 둘 다 필요. | `~/.config/cmux/*` |

**설치 순서: binbox → nvim → cmux-config** (`repos.txt` 줄 순서 = 의존 순서).

---

## 파일

| 파일 | 역할 |
|---|---|
| `bootstrap.sh` | **프로비저닝**(쓰기). clone/pull → 심볼릭 링크 → 각 repo setup. 멱등. |
| `upgrade.sh` | **최신 동기화**(쓰기). 각 repo 를 `sync_cmd` 로 최신화 (git pull + nvim 플러그인 복원 등). |
| `doctor.sh` | **상태 점검**(읽기 전용). repo·링크·의존계약 검사. 아무것도 안 바꿈. |
| `repos.txt` | **매니페스트**. 관리 대상 repo 목록 (한 줄 = 한 repo). |
| `DEPENDENCIES.md` | 상세 레퍼런스 (동작 흐름, 자동 실행 범위, 계약, repo 추가 방법). |

---

## 빠른 시작

### 새 장비

```bash
git clone https://github.com/jisung9870/dev-env-setup.git ~/home/setup   # 진입점만 먼저
cd ~/home/setup && ./bootstrap.sh          # 나머지 3개 clone + 연결 + 경량 셋업
exec $SHELL -l                             # 셸 rc 재적용
```

무거운 툴 설치(neovim, ripgrep, asdf 툴 등)는 bootstrap 자동 실행에서 **제외**돼 있다.
새 장비에서 한 번만:

```bash
cd ~/home/setup/nvim && ./scripts/setup.sh --install --link --with-font --with-tmux-plugins --yes
```

### 평소

```bash
cd ~/home/setup
./doctor.sh            # 상태 점검 (읽기 전용)
./upgrade.sh           # 세 repo 를 최신으로 동기화 — 평소 업데이트는 이거면 충분
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
| `./upgrade.sh` | 세 repo 를 의존 순서로 최신화 |
| `./upgrade.sh binbox` | 지정한 repo만 최신화 |
| `./doctor.sh` | repo/링크/의존계약 점검 (문제 있으면 종료코드 ≠ 0) |

> **bootstrap vs upgrade** — `bootstrap.sh` 는 *배치*(clone/link/setup, 새 장비·복구용,
> pull 은 부수효과), `upgrade.sh` 는 *최신 반영* 전용(각 repo 의 `sync_cmd`). 평소
> "업데이트 좀 당겨오자"는 `./upgrade.sh`.

---

## 더 읽기

- **[DEPENDENCIES.md](DEPENDENCIES.md)** — 동작 흐름, 무엇이 자동 실행되나, 계약(변경 시 같이
  고칠 것), repo 추가/변경 방법. 이 repo 를 손볼 때 먼저 읽는다.
- **[binbox/README.md](binbox/README.md)** — `bb` 도구 전체 목록과 사용법.
- **[nvim/README.md](nvim/README.md)** — LazyVim 설정 구조, 멀티 머신 동기화, 초기 설정.
- **[cmux-config/README.md](cmux-config/README.md)** — cmux 워크스페이스/작업판 관리.
