# 미결정 사항과 남은 단계

> 기준일: 2026-08-10
> 제품 방향과 MVP 선택은 [통합 기획서](../PRODUCT-PLAN.md), 선택 이유는
> [통합 판단](synthesis-and-decisions.md)을 따른다.

## 확인된 방향

- 최종 목표는 개인 업무와 개발을 함께 관리하는 local-first 개인 운영 환경이다.
- 통합 대상은 문서, 계획, 정보 수집, 실행, 반복 업무, 자동화와 외부 서비스지만 한 번에 만들지 않는다.
- 원문 소유권을 보존하고 Setup은 provenance, reference, projection, policy와 run journal을 연결한다.
- MCP는 여러 adapter 중 하나며 핵심 목표나 필수 transport가 아니다.
- Agent 관리·멀티 Agent orchestration은 제품 범위에 포함한다. 첫 선택은 Orca optional backend이며 자체
  scheduler/DAG는 증거가 생길 때까지 보류한다.
- binbox, tmux, LazyVim의 독립 경로는 복구 자산이며 삭제 목표로 삼지 않는다.
- WSL은 primary Tier-1이고 macOS는 같은 30일 smoke track에서 병행한다.
- 일반 설치는 `workbench` profile, 복구·최소 설치는 명시적 `terminal` profile을 사용한다.
- Markdown은 canonical authoring format이고 SQLite는 재구축 가능한 projection이다.
- 외부 read connector는 GitHub→Slack 순서로 검증한다.
- private GitHub는 Markdown·설정 history, OneDrive는 Secret을 제외한 암호화 backup snapshot에 사용한다.

## 다음 의사결정

| 순서 | 결정 | 필요한 근거 | 완료 판정 |
|---:|---|---|---|
| 1 | WSL·macOS 지원 판정 | 두 실제 장비의 동일 smoke | WSL Tier-1 유지, macOS 통과 시 함께 Tier-1 |
| 2 | 매일 대표 세 흐름 | 2주 category-only 사용 기록 | 실제 Inbox 20개, closed loop 3개 |
| 3 | Markdown 세부 계약 | frontmatter·rename·SQLite rebuild prototype | 수동 복구, export·reimport, migration fixture |
| 4 | GitHub·Slack scope | personal/work 계정, 최소 권한·retention | read-only 실제 사용과 revoke/disable 검증 |
| 5 | Orca E0→E1 | 2주 또는 Agent session 20개 | Orca 사용 30% 이상 또는 찾기 불편 3회 |
| 6 | GitHub/OneDrive 복구 | 별도 경로·암호화 snapshot fixture | Git history와 off-device restore 모두 성공 |
| 7 | 첫 제한 write | read adapter 가치와 conflict 사례 | preview, CAS/idempotency, journal, rollback fixture |

## 30일 남은 단계

1. 기본 `workbench`와 명시적 `terminal` profile 정책을 문서·selector·exit contract에서 일치시킨다.
2. lock snapshot을 검증 날짜, run ID, child commit과 rollback이 있는 manifest로 정의한다.
3. WSL에서 Tier-1 fresh setup/update/doctor와 synthetic restore를 수행하고 macOS에서 같은 smoke를 병행한다.
4. Markdown+최소 frontmatter를 canonical format으로 두고 SQLite rebuild를 포함한 schema spike를 검토한다.
5. file/stdin capture → Today/Next → resume → result/recovery review의 세로 흐름을 검증한다.
6. 로컬 opt-in usage 기록으로 capture·resume 시간, fallback, stale/partial 상태를 측정한다.
7. Orca E0를 수행하고 gate를 통과할 때만 read-only E1 adapter를 설계한다.

## 31~90일 후보

- 가장 큰 복귀/정리 마찰 한 개 개선
- recurring task와 weekly review
- GitHub read-only metadata 후 동일 core 계약을 재사용하는 Slack read-only adapter
- 두 번째 platform smoke와 지원 tier
- source-of-truth 문서 표, release/rollback 절차
- E1 성공 시 policy가 보이는 Orca controlled launch와 result pointer
- 실제 사용 중인 MCP가 있을 때만 read-only inventory 및 1 server/2 client 가역 실험

## 장기 재검토 gate

### 자체 Agent orchestration

다음 조건을 모두 만족해야 provider-neutral registry/control 또는 자체 orchestration을 검토한다.

- Orca와 non-Orca backend를 가로지르는 동일 목표 월 10회 이상
- read-only projection으로 해결되지 않는 audit/queue 불편 월 3회 이상
- 두 provider가 stable attempt ID와 terminal outcome 제공
- crash/restart/retry/late-completion fixture 선작성 가능
- 30일 shadow mode 상태 불일치 1% 미만, destructive action 0건

### Cloud/mobile

두 장비 또는 mobile capture가 반복적으로 closed loop를 막고, export+사용자 선택 sync로 해결되지 않을 때만
encrypted sync와 mobile share target을 별도 threat model로 검토한다.

### Generic integration framework

두 개 이상의 adapter에서 동일한 capability, cursor, health, disable/export 계약이 실제로 반복된 뒤에만
공통 plugin/RPC surface를 추출한다.

## 즉시 구현하지 않을 항목

- monorepo 전환
- 상시 cloud daemon, remote multi-user control
- arbitrary command runner와 자연어 파괴 작업
- 범용 MCP proxy, 자동 server 설치·update
- mail/calendar/Docs의 초기 양방향 sync
- 자체 scheduler, message bus, DAG, transcript state inference
- 별도 native desktop/mobile shell
- 사용 근거 없이 기존 fallback이나 binbox 명령 삭제

## 계속 열린 질문

1. 첫 20개 입력과 가장 자주 복귀하는 세 작업은 무엇인가?
2. Markdown frontmatter의 최소 필드, 파일 배치와 rename 규칙은 무엇인가?
3. GitHub·Slack의 personal/work account scope와 retention은 어디까지인가?
4. Git working tree와 OneDrive encrypted snapshot의 주기·보존·충돌 정책은 무엇인가?
5. Orca E0가 E1 승격 gate를 통과하는가?
6. 첫 제한 write의 action과 rollback 계약은 무엇인가?
7. macOS가 WSL과 같은 Tier-1 gate를 통과하는가?
