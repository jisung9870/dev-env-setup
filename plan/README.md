# Setup 제품 기획

이 디렉터리는 `dev-env-setup`과 네 개의 관리 저장소를 하나의 제품으로 다시 정의하기 위한
기획 공간이다.

- 상태: **공동 작성 초안**
- 기준일: 2026-08-10
- 현재 구현 기준: root `99f5c9f`, workbench `10347a9`, binbox `682e018`,
  nvim `d25dbfe`, cmux-config `f5e5195`
- 현재 기획서: [PRODUCT-PLAN.md](PRODUCT-PLAN.md)
- 사실 자료: [raw/README.md](raw/README.md)
- 이전 계획: [archive/2026-08-10-plan-v1/](archive/2026-08-10-plan-v1/)

## 문서 구조

| 위치 | 역할 | 편집 규칙 |
|---|---|---|
| [PRODUCT-PLAN.md](PRODUCT-PLAN.md) | 제품 정의, 우선순위, 성공 기준을 함께 결정하는 초안 | 합의된 결정과 검토 중인 선택지를 구분한다 |
| [raw/](raw/) | 코드·Git·검증 결과에서 수집한 현재 사실과 미결 과제 | 추측을 사실처럼 쓰지 않고 관찰 날짜와 근거를 남긴다 |
| [archive/](archive/) | 완료됐거나 대체된 계획과 구현 이력 | 현행 지시로 사용하지 않는다 |
| 각 저장소 README/docs | 구현·운영 계약 | 세부 동작의 최종 근거로 사용한다 |

## 지금 읽을 순서

1. [raw/current-system.md](raw/current-system.md) — 현재 실제 제품 구조와 기능
2. [raw/repository-baseline.md](raw/repository-baseline.md) — 저장소·플랫폼·lock 상태
3. [raw/validation-baseline.md](raw/validation-baseline.md) — 검증된 것과 검증되지 않은 것
4. [raw/backlog-and-open-questions.md](raw/backlog-and-open-questions.md) — 이전 계획에서 남은 후보와 새로 발견한 갭
5. [PRODUCT-PLAN.md](PRODUCT-PLAN.md) — 위 사실을 바탕으로 다시 작성한 기획 초안

## Source of truth

- 현재 동작은 코드, 테스트, 각 저장소의 구현 문서를 우선한다.
- `raw/`는 특정 시점의 관찰 기록이며 구현 자체를 대체하지 않는다.
- 제품 방향과 우선순위는 [PRODUCT-PLAN.md](PRODUCT-PLAN.md)에서 합의한다.
- 이전 Phase 번호와 완료 기록은 archive의 역사 자료일 뿐 새 로드맵의 자동 입력이 아니다.
- 사용자 로컬 변경은 제품 계획 정리 과정에서 수정하거나 삭제하지 않는다.

## 이번 재기획에서 결정할 것

- 이 제품의 중심을 “설치 저장소”와 “개인 개발환경 운영 시스템” 중 어디에 둘지
- Workbench를 필수 구성요소로 둘지 선택 기능으로 복원할지
- Linux/macOS/WSL/native Windows의 지원 수준과 증명 기준
- binbox·tmux·LazyVim의 독립 경로와 Workbench 기능이 겹치는 부분의 유지·축소 기준
- 배포, 버전, 호환 snapshot을 어떤 단위로 관리할지

결정되지 않은 항목은 구현 작업으로 자동 승격하지 않는다.
