# setup — 개인 환경 repo 의존 관계 & 관리

`~/home/setup/` 은 여러 장비에서 **동일한 개인 환경**을 재현하기 위한 오케스트레이션 레이어입니다.
3개 repo는 각각 독립된 GitHub 저장소로 유지하고, 이 폴더의 스크립트가 **의존 순서대로 설치·연결·점검**합니다.

## 의존 그래프

```
        cmux-config          ← 오케스트레이션 (워크스페이스/패널에서 bb·nvim 실행)
        │        │
   (bb 명령)   (nvim 실행)
        ▼        ▼
     binbox      nvim
        ▲         ╎
        ╰┈┈┈┈┈┈┈┈┈╯  nvim → binbox 'tm' 포맷 참조 (약함)
```

- **binbox** (기반) — `bb` 디스패처 툴킷. 의존 없음. `bb setup` 이 `~/.local/bin/bb` 링크 + 셸 rc 등록.
- **nvim** (repo: lazyvim-config) — 에디터 설정. binbox 의 `tm`(tmux 레이아웃) 포맷을 느슨하게 참조.
- **cmux-config** — cmux 워크스페이스 정의. 패널에서 `bb <tool>` 과 `nvim` 을 직접 호출 → **둘 다 필요**.

**설치 순서: binbox → nvim → cmux-config** (repos.txt 줄 순서와 동일).

## 계약 (바꿀 때 같이 고쳐야 하는 것)

| 바뀌는 곳 | 영향 받는 곳 | 확인할 파일 |
|---|---|---|
| binbox `libexec/<tool>` 이름 변경/삭제 | cmux 가 부르는 `bb <tool>` | `cmux-config/config.d/commands/*.json`, `actions/*.json` |
| binbox `tm` 레이아웃 포맷 변경 | nvim 파싱 | `nvim/lua/plugins/editor.lua` |
| 배포 경로(`~/binbox`, `~/.config/nvim`) 변경 | cmux `cwd`, 각종 참조 | `repos.txt`, cmux `commands/tools.json` |

→ `./doctor.sh` 가 `bb <tool>` ↔ `binbox/libexec` 대조로 계약 깨짐을 자동 감지합니다.

## 사용법

```bash
cd ~/home/setup
./doctor.sh              # 상태 점검 (읽기 전용)
./bootstrap.sh           # 전체 프로비저닝 (clone/pull → link → 각 repo setup)
./bootstrap.sh --link-only   # 심볼릭 링크만 복구 (경로 이동 후 등, 안전)
./bootstrap.sh --no-setup    # rc/설정 건드리지 않고 clone/pull/link 만
./bootstrap.sh binbox        # 특정 repo만
```

## 새 장비 세팅

```bash
git clone <이 setup 저장소> ~/home/setup   # 진입점만 먼저
cd ~/home/setup && ./bootstrap.sh          # 나머지 3개 clone + 연결 + 셋업
exec $SHELL -l                             # 셸 rc 재적용
```

## repo 추가/변경

`repos.txt` 에 한 줄 추가: `name | git_url | link_target | setup_cmd`
(줄 위치 = 설치 순서. 의존이 있으면 의존 대상보다 아래에.)

## 배포 링크 (현재 장비)

| repo | 물리 위치 | 런타임 링크 |
|---|---|---|
| binbox | `~/home/setup/binbox` | `~/binbox`, `~/.local/bin/bb` |
| nvim | `~/home/setup/nvim` | `~/.config/nvim` |
| cmux-config | `~/home/setup/cmux-config` | `~/.config/cmux/*`, `~/Library/Application Support/com.cmuxterm.app/*` |
