# 저장소 기준선

## Git 상태

| 저장소 | 역할 | HEAD | origin 동기화 | working tree |
|---|---|---:|---|---|
| dev-env-setup | 전체 선택·설치·업데이트·통합 검증 | `99f5c9f` | 동기화 | clean |
| workbench | 상태 core, backend, Dashboard | `10347a9` | 동기화 | clean |
| binbox | `bb` 운영 toolbox | `682e018` | 동기화 | clean |
| nvim | LazyVim·tmux 설정과 client | `d25dbfe` | 동기화 | `lazy-lock.json` 사용자 변경 존재 |
| cmux-config | macOS cmux client/config | `f5e5195` | 동기화 | clean |

원격은 각각 `jisung9870/dev-env-setup`, `workbench`, `binbox`,
`lazyvim-config`, `cmux-config`다.

## 설치 매니페스트

`repos.txt`의 설치 순서는 다음과 같다.

1. binbox
2. nvim
3. cmux-config
4. workbench

각 저장소는 독립 Git repository이며 root 저장소는 child 디렉터리를 추적하지 않는다. root는
`bootstrap.sh`, `upgrade.sh`, `doctor.sh`, `repos.txt`, platform profile과 lock snapshot만
소유한다.

## Platform selector

| platform ID | binbox | nvim | cmux-config | workbench |
|---|---|---|---|---|
| `linux` | required | required | disabled | required |
| `macos` | required | required | optional | required |
| `windows-wsl` | required | required | disabled | required |
| `windows-native` | **profile 없음** | **profile 없음** | **profile 없음** | **profile 없음** |

Workbench 코드는 native Windows target과 Windows Terminal backend를 구현하지만 root selector는
`windows-native`를 지원하지 않는다. 따라서 “코드 target 지원”과 “setup 제품의 장비 지원”을 같은
의미로 쓰면 안 된다.

## Lock snapshot drift

`locks/repos.lock`은 report-only snapshot이며 현재 child HEAD와 다음처럼 다르다.

| 저장소 | lock | 현재 | 상태 |
|---|---:|---:|---|
| binbox | `b7e4bc9` | `682e018` | drift |
| nvim | `90d7386` | `d25dbfe` | drift |
| cmux-config | `f5e5195` | `f5e5195` | 일치 |
| workbench | `6bca9f9` | `10347a9` | drift |

새 기획에서는 lock을 release 기준선으로 사용할지, 단순 관찰 snapshot으로 유지할지 다시 결정해야 한다.

## 확인된 표현 충돌

- root README는 Workbench를 선택적 core라고 설명하지만 platform profile은 workbench를 required로
  선택한다.
- Workbench는 native Windows build target을 제공하지만 root provisioning은 native Windows profile을
  제공하지 않는다.
- 이전 기획은 Phase 6을 다음 단계로 지정했지만 실제 사용 관찰과 장비 smoke가 없어 우선순위 근거가
  충분하지 않다.
