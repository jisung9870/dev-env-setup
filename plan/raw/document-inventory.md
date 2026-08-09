# 관리 문서 인벤토리

## 현행 진입점

| 문서 | 역할 |
|---|---|
| root `README.md` | 설치와 일상 명령을 안내하는 사용자 진입점 |
| root `DEPENDENCIES.md` | repository orchestration과 변경 계약 |
| root `WORKBENCH-PLAN.md` | 기존 bookmark를 새 plan으로 연결하는 호환 진입점 |
| `plan/README.md` | 재기획 문서 구조와 읽기 순서 |
| `plan/PRODUCT-PLAN.md` | 공동 작성할 제품 기획 초안 |
| `plan/raw/*` | 현재 사실, 검증, 미결 과제 |
| 각 child README/docs | 해당 구현의 상세 계약 |

## 2026-08-10 archive 이동

다음 기존 plan v1 문서와 그 SVG 자산은
`plan/archive/2026-08-10-plan-v1/`로 이동했다.

- 배경과 당시 현재 상태
- 결정과 목표 아키텍처
- Workbench CLI·데이터 계약
- UI·client 사양
- 저장소 변경 지도
- 검증·보안·운영 기준
- 세션·장비 handoff
- Personal Workbench 제품 기획
- cross-platform architecture SVG
- Dashboard wireframe SVG

이 자료는 당시 판단과 구현 이력을 보존하지만 현행 source of truth가 아니다.

## 별도 archive

- `archive/04-implementation-roadmap.md`: 초기 Phase 구현 이력
- `archive/08-phase4-cleanup-plan.md`: cleanup pass 기록
- `archive/09-unified-workbench-tmux-roadmap.md`: tmux 통합 방향의 이전 제안

## 중복 관리 원칙

- 설치 명령은 root README에 한 번만 설명하고 plan에서는 링크한다.
- 구현 세부 명령과 schema는 child docs가 소유한다.
- raw에는 전체 명령 목록을 복제하지 않고 제품 기능 범주만 기록한다.
- 완료된 계획은 수정해 현행화하지 않고 archive로 이동한다.
- 새 기획서에는 제품 결정, 우선순위, 성공 기준만 둔다.
