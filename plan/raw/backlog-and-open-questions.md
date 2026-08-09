# 후보 과제와 미결 질문

이 문서는 이전 계획의 “남은 단계”와 현재 조사에서 발견한 갭을 보존한다. 순서, Phase, 구현 승인은
아직 정하지 않았다.

## 사용자에게서 확인된 장기 방향

- 최종 목표는 단순 개발환경 설치가 아니라 개인 업무와 개발을 위한 나만의 도구 플랫폼이다.
- MCP 관리는 Codex·Claude·에디터·업무 서비스를 연결하는 관리 영역 후보로 포함한다.
- 구체적인 MCP 기능 범위와 구현 순서는 아직 결정하지 않았다.

## 이전 계획에서 이관한 후보

| 후보 | 이전 의도 | 현재 근거 | 재결정할 점 |
|---|---|---|---|
| 대표 사용 관찰 | project picker와 Agent list의 primary/fallback 사용 기록 | compatibility 관찰 기능은 구현됨 | 어떤 사용 주기와 표본이면 충분한가 |
| compatibility 경로 정리 | nvim project/Agent fallback, `bb wenv`, `bb sec`를 warning→shim→제거로 평가 | 독립 경로가 여전히 운영 가치가 있음 | 제거가 목표인지 역할 명확화가 목표인지 |
| 물리 장비 smoke | Linux/macOS/Windows/WSL/cmux 실제 흐름 확인 | cross-build와 fake E2E만으로 부족 | 지원 tier와 필수 장비 조합 |
| 공개 배포 판정 | release/tag/versioned compatibility 검토 | 현재는 source checkout 중심 | 개인용 배포에 release가 필요한가 |
| Worktree client 확장 | LazyVim 또는 Dashboard에서 create/remove | core 안전 계약은 구현됨 | 실제 사용 빈도와 UI 필요성 |
| backend 공통 session lifecycle | tmux 외 surface ownership 확대 | 신뢰 가능한 stable ID가 backend마다 다름 | 공통 추상화가 실제 가치를 주는가 |
| cmux action 동기화 | project registry 변경 시 generated action drift 감소 | 수동 generator/check가 존재 | 자동화 위치와 쓰기 권한 |

## 이번 조사에서 새로 확인한 후보

| 후보 | 관찰 | 위험 |
|---|---|---|
| lock snapshot 정책 재정의 | 4개 중 3개 child commit이 lock과 다름 | “검증된 조합” 의미가 약해짐 |
| Workbench required/optional 결정 | 문서는 optional, platform profile은 required | 설치 실패 정책과 제품 메시지가 충돌 |
| native Windows 지원 범위 | Workbench target은 있으나 root platform profile 없음 | 지원 주장과 실제 bootstrap 경험 불일치 |
| toolchain 발견성 | Go/Node/bats가 설치돼도 일반 PATH에서 shim 해석 실패 | 검증·설치 명령이 장비별로 달라짐 |
| 관리 문서 중복 축소 | root README, DEPENDENCIES, child docs, 이전 plan이 같은 설명 반복 | drift와 긴 인수인계 비용 |
| 운영 telemetry 최소화 | compatibility 관찰 외 실제 사용 근거가 없음 | 감으로 fallback을 제거할 가능성 |
| MCP 관리 inventory | client별 server/config/Secret 경계가 아직 수집되지 않음 | 성급한 공통화가 설정과 권한을 더 복잡하게 만들 수 있음 |

## 제품 기획에서 먼저 답할 질문

1. 매일 반드시 쓰는 세 개의 업무·개발 흐름은 무엇인가?
2. 첫 MCP 대상 client와 server 조합은 무엇인가?
3. Workbench 장애 시 terminal 독립 경로를 어느 수준까지 보장할 것인가?
4. native Windows는 core build target인가, 전체 setup 지원 platform인가?
5. lock은 재현 가능한 release manifest인가, 최신 관찰 상태인가?
6. 중복 명령의 성공 기준은 제거 개수인가, 책임과 복구 경로의 명확성인가?
7. Dashboard와 background server가 실제 일상 기본 경로인지 선택 도구인지?
8. 공개 release 없이도 개인 장비 간 안정적 배포가 가능한가?
9. MCP 설정의 source of truth를 root manifest와 Workbench registry 중 어디에 둘 것인가?
10. MCP lifecycle에서 catalog·health 이후 enable/disable·update까지 어디까지 자동화할 것인가?

## 즉시 구현으로 넘기지 않을 항목

- monorepo 전환
- 상시 daemon 또는 cloud sync
- arbitrary command runner
- 팀·조직용 multi-user 권한
- 별도 native desktop shell
- 사용 근거 없는 범용 MCP proxy 또는 generic plugin/RPC framework

이 항목들은 명시적인 문제 증거와 새 결정 기록이 생길 때만 다시 검토한다.
