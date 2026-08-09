# Raw 자료

이 디렉터리는 새 제품 기획서를 작성하기 전에 수집한 현재 상태의 근거다. 결론을 정당화하기 위해
사실을 골라 쓰지 않고, 충돌하거나 불완전한 상태도 그대로 기록한다.

- 수집일: 2026-08-10
- 수집 위치: `/home/ubuntu/setup`
- 기준 branch: 모든 저장소 `main`
- 네트워크 상태: 각 branch는 수집 시점에 `origin/main`과 동기화
- 예외: `nvim/lazy-lock.json`에 기존 사용자 변경이 있으며 수집·정리 과정에서 건드리지 않음

## 자료 목록

| 파일 | 내용 |
|---|---|
| [repository-baseline.md](repository-baseline.md) | 저장소 commit, dirty state, platform selector, lock snapshot |
| [current-system.md](current-system.md) | 현재 책임 구조, 기능 표면, 데이터와 실행 경계 |
| [validation-baseline.md](validation-baseline.md) | 실행한 검증, 통과 범위, 아직 증명하지 못한 범위 |
| [backlog-and-open-questions.md](backlog-and-open-questions.md) | 이전 계획의 남은 단계와 현재 새로 발견한 후보 과제 |
| [document-inventory.md](document-inventory.md) | 현행·구현·archive 문서의 역할과 이동 기록 |

## 기록 원칙

- “지원한다”는 코드, 테스트, 또는 실제 장비 smoke 중 근거가 있는 수준으로 한정한다.
- 자동화된 cross-build는 실제 장비 동작을 증명하지 않는다.
- 문서와 코드가 충돌하면 충돌 자체를 기록하고 기획 단계에서 결정한다.
- backlog 항목은 후보일 뿐 우선순위나 구현 승인을 뜻하지 않는다.
- Secret 값, 개인 경로의 민감 내용, 실행 로그 전문은 수집하지 않는다.
