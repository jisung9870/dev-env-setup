# Raw 조사와 현재 상태

이 디렉터리는 통합 제품 기획에 사용한 관찰 기록과 멀티 에이전트 조사 원문을 보존한다. 워커 보고서는
결과뿐 아니라 근거, 반론과 불확실성을 포함하며, 최종 선택은
[synthesis-and-decisions.md](synthesis-and-decisions.md)에 별도로 기록한다.

- 수집일: 2026-08-10
- 수집 위치: `/home/ubuntu/setup`
- 기준 branch: root와 네 child 모두 `main`
- Git 예외: `nvim/lazy-lock.json`에 기존 사용자 변경이 있으며 이번 작업에서 건드리지 않음
- Orca orchestration run: `run_effd9e1cba83`

## 현재 상태 자료

| 파일 | 내용 |
|---|---|
| [repository-baseline.md](repository-baseline.md) | 저장소 commit, dirty state, platform selector, lock snapshot |
| [current-system.md](current-system.md) | 현재 책임 구조, 기능 표면, 데이터·실행 경계 |
| [validation-baseline.md](validation-baseline.md) | 실행한 검증과 아직 증명하지 못한 범위 |
| [document-inventory.md](document-inventory.md) | 현행·구현·archive 문서 역할과 이동 기록 |
| [backlog-and-open-questions.md](backlog-and-open-questions.md) | 남은 결정, 검증 gate와 후속 후보 |

## 멀티 에이전트 조사 원문

| 영역 | 파일 | 핵심 질문 |
|---|---|---|
| A 제품 전략 | [product-strategy-research.md](product-strategy-research.md) | 어떤 문제와 차별화를 선택하고 무엇을 하지 않을까 |
| B 시나리오 | [user-scenarios-and-features.md](user-scenarios-and-features.md) | 실제 하루와 capture→automation 루프에 무엇이 필요한가 |
| C 기술·보안 | [technical-integration-security.md](technical-integration-security.md) | local-first, adapter, UI, 권한·감사·복구 계약은 현실적인가 |
| D 우선순위 | [prioritization-and-roadmap.md](prioritization-and-roadmap.md) | 가치·비용·위험으로 MVP를 어디까지 제한할까 |
| E Agent/Orca | [agent-management-orchestration.md](agent-management-orchestration.md) | Orca를 연결할지 직접 만들지, ownership과 승격 gate는 무엇인가 |
| 통합 판단 | [synthesis-and-decisions.md](synthesis-and-decisions.md) | 보고서의 충돌 중 무엇을 채택했고 왜 그런가 |

## 기록 원칙

- 최신 외부 사실은 공식 문서와 신뢰할 수 있는 1차 자료를 우선한다.
- 사실, 추론과 제안을 문맥 또는 표기로 구분한다.
- 제품 이름을 나열하기보다 Setup의 경계와 의사결정에 주는 시사점을 기록한다.
- “지원한다”는 build, fixture, 실제 장비 smoke 중 근거가 있는 수준으로 한정한다.
- backlog와 실험은 후보이며 구현 승인을 뜻하지 않는다.
- Secret 값, prompt·terminal 전문과 민감한 개인 경로는 수집하지 않는다.
