# Setup 제품 기획

이 디렉터리는 `dev-env-setup`과 네 개의 관리 저장소를 local-first 개인 운영 환경으로 발전시키기 위한
현행 제품 기획 공간이다.

- 상태: **통합 방향 확정, MVP 검증 전**
- 기준일: 2026-08-10
- 현재 구현 기준: root `d9462cc`, workbench `10347a9`, binbox `682e018`,
  nvim `d25dbfe`, cmux-config `f5e5195`
- 현행 기획서: [PRODUCT-PLAN.md](PRODUCT-PLAN.md)
- 목표 아키텍처: [ARCHITECTURE.md](ARCHITECTURE.md)
- 단계별 전달 계획: [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md)
- Dashboard 제품·UX 명세: [DASHBOARD-SPEC.md](DASHBOARD-SPEC.md)
- 통합 판단: [raw/synthesis-and-decisions.md](raw/synthesis-and-decisions.md)
- 이전 계획: [archive/2026-08-10-plan-v1/](archive/2026-08-10-plan-v1/)

## 문서 구조

| 위치 | 역할 | 사용 규칙 |
|---|---|---|
| [PRODUCT-PLAN.md](PRODUCT-PLAN.md) | 제품 정의, 원칙, MVP, roadmap, 성공·중단 기준 | 현행 제품 결정의 source of truth |
| [ARCHITECTURE.md](ARCHITECTURE.md) | component ownership, current/planned 구분, data class와 data flow | Phase 0 목표 architecture contract |
| [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md) | S0–S9 dependency, stage deliverable, acceptance, cutoff/rollback | 구현 순서와 stage gate의 source of truth |
| [DASHBOARD-SPEC.md](DASHBOARD-SPEC.md) | Dashboard IA, 화면 상태, Core/API/action 안전 계약, 단계별 인수 기준 | Phase 0 Dashboard target contract |
| [raw/](raw/) | 현재 상태, 분야별 조사 원문, 반론·불확실성, 통합 판단 | 특정 시점의 근거이며 구현 자체를 대체하지 않음 |
| [archive/](archive/) | 완료·대체된 계획과 구현 이력 | 현행 지시로 사용하지 않음 |
| root/child README와 docs | 실제 설치·운영·schema·명령 계약 | 구현 세부의 source of truth |

## 읽는 순서

1. [PRODUCT-PLAN.md](PRODUCT-PLAN.md) — 선정된 제품 방향과 제한된 MVP
2. [ARCHITECTURE.md](ARCHITECTURE.md) — 목표 ownership, data class와 client parity
3. [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md) — S0–S9 전달 순서와 acceptance/cutoff
4. [DASHBOARD-SPEC.md](DASHBOARD-SPEC.md) — Dashboard와 CLI/Core의 목표 UX·안전 계약
5. [raw/synthesis-and-decisions.md](raw/synthesis-and-decisions.md) — 워커 간 충돌과 선택 이유
6. [raw/current-system.md](raw/current-system.md) — 현재 구현 자산과 책임 경계
7. [raw/repository-baseline.md](raw/repository-baseline.md) 및
   [raw/validation-baseline.md](raw/validation-baseline.md) — Git·지원·검증 기준선
8. [raw/README.md](raw/README.md)의 A–E 조사 원문 — 사실, 근거, 반론과 불확실성
9. [raw/backlog-and-open-questions.md](raw/backlog-and-open-questions.md) — 아직 결정하지 않은 항목과 다음 gate

## 이번 기획에서 확정한 것

- 제품은 설치 도구나 Workbench IDE가 아니라 개인 업무와 개발 맥락을 연결하는 local-first 운영 환경이다.
- 첫 제품 쐐기는 `Prepare → Resume → Recover`이고, 30일에는 신뢰 기반과 한 개의 닫힌 개인 운영 loop만 만든다.
- 외부 원문은 복제보다 reference/projection으로 연결하며 개인/업무 credential과 write 권한을 분리한다.
- MCP는 file, Git, API, webhook, CLI와 같은 adapter 선택지 중 하나다.
- Orca는 유일한 제품 workspace와 Agent runtime이지만 canonical state dependency는 아니다. Workbench는
  Orca runtime을 복제하지 않고, Orca 장애 시 자동 terminal 전환이 아닌 수동 `wb`/Markdown/Git
  break-glass 경로를 유지한다.
- Dashboard는 operations console을 버리지 않고 Today/Inbox/Projects/Runs & Agents/Integrations/System & Recovery로
  발전하며, `wb` CLI와 같은 Workbench Core를 사용한다.
- Orca는 WSL과 macOS의 단일 terminal workspace다. Windows Terminal/iTerm2/cmux는 신규 제품 경로에서
  제외하고, tmux는 Orca worktree별 human work partition으로 유지하며 Agents는 Orca에서 직접 실행한다.
- 자체 Agent scheduler/message bus/DAG, cloud sync, native app과 폭넓은 양방향 연동은 사용 gate까지 보류한다.
- WSL은 primary Tier-1이며 macOS를 같은 30일 smoke track에서 병행한다.
- 일반 설치는 `workbench` profile, 복구·최소 설치는 명시적 `terminal` profile을 사용한다.
- Markdown을 canonical authoring format으로 두고 SQLite는 재구축 가능한 index로 제한한다.
- GitHub→Slack 순으로 read connector를 검증하고, private GitHub와 암호화된 OneDrive backup을 역할별로 사용한다.

## Source of truth와 보존

- 동작이 문서와 충돌하면 코드, 테스트와 각 구현 문서가 우선하며 충돌을 raw에 기록한다.
- 제품 방향과 우선순위는 [PRODUCT-PLAN.md](PRODUCT-PLAN.md)가 소유한다.
- 완료된 이전 계획과 SVG는 archive에 보존한다. 활성 영역에서 추가로 이동할 완료 계획은 현재 없다.
- `WORKBENCH-PLAN.md`는 기존 링크를 현행 plan으로 연결하는 호환 진입점으로 유지한다.
- binbox 명령 문서는 독립 terminal 운영·복구 경로이므로 삭제·정리 대상이 아니다.
- 사용자 로컬 변경, 특히 `nvim/lazy-lock.json`의 기존 변경은 기획 작업에서 수정하지 않는다.
