# 기능 우선순위와 로드맵

> 상태: 평가 초안
> 기준일·외부 자료 확인일: **2026-08-10**
> 평가 대상: root setup, binbox, nvim/tmux, cmux-config, Workbench, 향후 외부 서비스 연동
> 전제: 개인용, terminal-first, local-first, 사용자 통제·보안·복구·서비스 비종속 우선

이 문서는 구현된 기능을 다시 나열하는 backlog가 아니다. 현재 제품에서 어떤 문제를 먼저 증명하고,
어떤 기능을 의도적으로 미룰지를 같은 척도로 판단한다. 아래의 **사실**은 코드·현행 문서·검증 기록에서
확인한 내용이고, **추론**은 그 사실의 제품적 의미이며, **제안**은 아직 합의나 구현 승인이 아닌 권고다.

## 1. 판단의 출발점

### 확인된 사실

- root setup은 네 child repository를 platform profile에 따라 선택하고 clone/pull/link/setup하며,
  `doctor.sh`와 contract test를 제공한다. pull은 추적 변경이 있으면 건너뛰고 fast-forward only로 수행한다.
  근거: [root README](../../README.md), [DEPENDENCIES](../../DEPENDENCIES.md).
- Workbench에는 project, environment, local Secret, managed tmux session, Git worktree, Agent/Task,
  typed workflow, doctor, overview, loopback Dashboard가 이미 구현돼 있다. 외부 worktree와 observed process는
  관찰만 하고, Dashboard는 임의 shell을 실행하지 않는다. 근거: [현재 시스템](current-system.md),
  [Workbench README](../../workbench/README.md).
- 자동 검증은 Go test, Windows cross-build, Dashboard Node test, root contract, binbox test, aggregate
  doctor, fake-provider E2E까지 통과했다. 반면 실제 macOS+cmux, Windows Terminal+WSL, native Windows,
  별도 Linux 장비, 장기 server/scheduler와 실제 사용 빈도는 이번 기준선에서 증명되지 않았다. 근거:
  [검증 기준선](validation-baseline.md).
- Workbench를 optional core라고 설명하는 문서와 모든 현행 platform profile에서 required로 취급하는 배포
  정책이 충돌한다. 네 child 중 세 개의 HEAD도 report-only lock snapshot과 다르다. 근거:
  [저장소 기준선](repository-baseline.md).
- MCP client/server/config/Secret 경계의 현황 inventory는 아직 없다. MCP는 장기 통합 방식 중 하나이고,
  범용 proxy나 모든 Secret 중앙화는 합의된 범위가 아니다. 근거:
  [후보 과제](backlog-and-open-questions.md), [제품 기획](../PRODUCT-PLAN.md).

### 제품적 추론

1. 지금의 가장 큰 결손은 기능 수가 아니라 **지원 주장과 실제 복구 증거 사이의 간격**이다.
2. Workbench의 넓은 기능 표면에 새 추상화를 더하면, 한 명이 운영하는 제품의 회귀·문서·migration 부담이
   사용자 가치보다 먼저 증가할 가능성이 높다.
3. 매일 쓰는 복귀 흐름은 가치가 크지만 Dashboard가 그 기본 경로인지, `wb`/tmux/LazyVim의 보조 경로인지
   아직 사용 증거가 없다. 기존 경로를 없애기보다 owner/fallback을 먼저 측정해야 한다.
4. MCP는 client별 scope·설정·인증 차이와 로컬 server 실행 위험이 있으므로, 바로 control plane을 만들기보다
   inventory와 한 개의 가역적 실험으로 계약을 발견하는 편이 안전하다.

## 2. 일관된 평가 척도

모든 항목을 1~5로 평가한다. `가치`, `빈도`, `검증`은 높을수록 좋고, `비용`, `운영`, `보안`,
`종속`은 높을수록 부담이 크다.

| 축 | 1점 | 3점 | 5점 |
|---|---|---|---|
| 사용자 가치(V) | 편의 개선 | 반복 마찰 감소 | 시작·복귀·복구 실패를 직접 줄임 |
| 사용 빈도(F) | 분기 이하 | 월간/특정 장비 | 거의 매일/매 작업 |
| 구현 비용(C) | 문서·작은 계약 | 한 component 변경 | 다중 repo/schema/client 변경 |
| 운영 부담(O) | 거의 없음 | 주기 점검 필요 | daemon·migration·지속 호환 필요 |
| 보안 위험(S) | 읽기 전용/로컬 metadata | 제한된 로컬 mutation | credential·외부 write·임의 실행 |
| 외부 종속성(D) | 표준 파일/Git | 특정 OS/tool | 특정 vendor/API/서비스 필수 |
| 검증 가능성(T) | 결과가 모호함 | fixture/수동 확인 | 결정적 test·smoke·복구 시험 가능 |

비교 점수는 다음 식으로 0~100 범위에 환산한다.

```text
점수 = round(100 × [2V + F + T + (6-C) + (6-O) + (6-S) + (6-D)] / 40)
```

가치를 2배로 두되 네 부담 축을 모두 감점한다. 점수는 정렬 도구이지 자동 승인 규칙이 아니다.
`핵심`은 높은 점수에 더해 다른 판단의 선행조건이어야 하고, 보안·종속 불확실성이 큰 항목은 점수가
높아도 `실험`으로 제한한다.

## 3. 후보 평가와 분류

| 분류 | 후보 | V | F | C | O | S | D | T | 점수 | 판정 근거 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| **핵심** | 제품 경계와 Workbench profile 정책 확정 | 5 | 5 | 2 | 1 | 1 | 1 | 5 | 98 | 설치 성공의 의미를 먼저 고정해야 함 |
| **핵심** | prerequisite preflight와 실패 복구 안내 | 5 | 3 | 2 | 1 | 1 | 1 | 5 | 93 | Go/PATH 발견성 갭, 새 장비 성공에 직결 |
| **핵심** | lock을 검증 조합 manifest로 재정의 | 5 | 2 | 2 | 2 | 1 | 1 | 5 | 88 | 현재 3/4 drift로 재현 주장 약화 |
| **핵심** | 단일 Tier-1 장비의 빈 환경→doctor→복구 smoke | 5 | 3 | 3 | 3 | 2 | 2 | 5 | 80 | cross-build가 대체하지 못하는 핵심 증거 |
| **핵심** | 대표 시작·업데이트·복귀 여정 사용 기록 | 4 | 4 | 2 | 2 | 2 | 1 | 4 | 83 | fallback 제거·UI 투자의 판단 근거 |
| **핵심** | 설정/state backup 복원 훈련 | 5 | 1 | 3 | 2 | 2 | 1 | 5 | 80 | local-first의 복구 가능성을 실제로 증명 |
| **차기** | 문서 source-of-truth와 owner 정리 | 4 | 3 | 2 | 2 | 1 | 1 | 5 | 85 | 높은 가치이나 MVP 동작 증명 뒤 정리 가능 |
| **차기** | project/session/worktree/Agent 복귀 흐름 다듬기 | 5 | 5 | 3 | 3 | 2 | 1 | 4 | 85 | 일상 가치 높음, 먼저 관찰 결과로 범위 제한 |
| **차기** | tag/release와 lock 갱신·rollback 절차 | 4 | 2 | 3 | 3 | 1 | 2 | 5 | 75 | 검증 조합을 장비 간 배포하는 후속 계약 |
| **차기** | 두 번째 platform 인증(WSL 우선 후보) | 4 | 3 | 4 | 4 | 2 | 3 | 5 | 68 | 실제 장비 확보와 반복 운영 비용 필요 |
| **차기** | compatibility 경로 유지·shim·제거 판정 | 3 | 2 | 3 | 3 | 3 | 1 | 5 | 68 | 대표 사용 기간과 회귀 시험 뒤에만 가능 |
| **차기** | MCP client/server/config/Secret 읽기 전용 inventory | 4 | 3 | 2 | 2 | 3 | 3 | 5 | 75 | 구현 전 경계 발견, 평문 수집은 금지 |
| **실험** | 로컬 category-only 사용 근거 수집 | 3 | 4 | 3 | 3 | 3 | 1 | 4 | 70 | 유용하나 수집 자체가 제품 목적이 되면 안 됨 |
| **실험** | Worktree create/remove client 확장 | 3 | 2 | 3 | 3 | 2 | 1 | 4 | 68 | core 계약은 있으나 UI 필요 빈도 불명 |
| **실험** | MCP 1 server→2 clients 설정 생성·health·rollback | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 58 | 방향성은 크나 client drift·credential 위험 큼 |
| **실험** | Dashboard를 일상 기본 복귀점으로 사용 | 3 | 2 | 3 | 4 | 3 | 2 | 4 | 60 | 현재는 보조 ops UI인지 기본 UI인지 미증명 |
| **실험** | cmux action 자동 동기화 | 2 | 2 | 4 | 4 | 3 | 3 | 4 | 50 | macOS 단일 provider 가치와 쓰기 소유권 불명 |
| **보류** | MCP enable/disable·자동 update lifecycle | 3 | 2 | 5 | 5 | 5 | 5 | 3 | 38 | 공급망·rollback·client별 동작을 먼저 증명해야 함 |
| **보류** | backend 공통 session lifecycle | 2 | 2 | 5 | 5 | 4 | 3 | 3 | 40 | 안전한 stable ID가 없는 backend가 존재 |
| **보류** | native Windows 전체 setup 지원 | 2 | 1 | 5 | 5 | 4 | 4 | 3 | 35 | core cross-build와 전체 지원을 분리해야 함 |
| **보류** | 범용 MCP proxy/plugin/RPC framework | 2 | 2 | 5 | 5 | 5 | 5 | 2 | 30 | 실제 반복 사례 전에는 서비스·보안 부담 과다 |
| **보류** | cloud sync·팀 multi-user control plane | 1 | 1 | 5 | 5 | 5 | 5 | 2 | 23 | 현재 개인/local-first 범위와 충돌 |

### 분류 규칙

- **핵심:** 30일 MVP 안에 끝내지 않으면 제품의 “재현·복구 가능” 주장을 믿기 어려운 것.
- **차기:** 가치가 확인됐지만 MVP 증거나 실제 사용 결과에 의존하는 것.
- **실험:** 작은 가역 실험으로 불확실성을 줄일 수 있으나 제품 기능으로 승격되지 않은 것.
- **보류:** 현재의 문제 증거보다 운영·보안·종속 비용이 큰 것. roadmap 날짜를 배정하지 않는다.

## 4. 강하게 제한한 MVP

### MVP에 포함

1. 제품 정의를 “개인 업무·개발 도구 플랫폼”으로 고정하되, **첫 전달물은 환경 재현과 작업 복귀의
   신뢰성**으로 한정한다.
2. profile을 최소 두 개로 정의한다.
   - `terminal`: binbox+nvim/tmux는 required, Workbench는 optional/partial.
   - `workbench`: 위 구성과 Workbench toolchain·core가 required.
3. Tier-1 platform은 30일 동안 실제 접근 가능한 **한 종류만** 선언한다. 현 환경만으로 시작하면 Linux,
   실제 주 사용 장비가 WSL이면 WSL을 선택하되 둘 다 동시에 “완료”로 잡지 않는다.
4. selection→preflight→bootstrap→doctor→대표 project 복귀→backup 복원까지 하나의 가역 runbook과
   증거 묶음을 만든다.
5. lock은 “마지막으로 이 runbook을 통과한 child commit 조합”으로 정의한다. 최신 HEAD 목록으로
   자동 갱신하지 않는다.
6. 2주 이상 대표 여정의 category, 성공/실패, primary/fallback, 소요 구간만 로컬에 기록한다.
   command, path, output, Secret은 기록하지 않는다. 자동 telemetry가 없어도 수동 표로 시작한다.

### MVP에서 제외

- 새 Dashboard panel, 새 backend, native Windows profile, worktree UI 확장.
- compatibility 명령 삭제와 monorepo 전환.
- MCP server 설치·업데이트·enable/disable, proxy, Secret 중앙화.
- cloud sync, 원격 제어, multi-user, 임의 command runner.
- 공개 release 자동화. MVP에서는 검증된 commit 조합과 복구 tag 초안까지만 다룬다.

이 제한은 기존 Workbench 기능을 폐기한다는 뜻이 아니다. 30일 동안 새 기능을 동결하고 현재 기능을
대표 여정에서 사용해 증거를 모은다는 뜻이다.

## 5. 단계별 로드맵

### 0~30일 — 신뢰성 MVP

**목표:** 한 장비 유형에서 설치·업데이트·복귀·복원이 예측 가능하다는 것을 증명한다.

1. D2(Workbench profile 정책), D3(첫 Tier-1 platform), D5(lock 의미)를 결정 기록으로 확정한다.
2. 쓰기 없는 `--show-selection`과 prerequisite preflight가 필요한 runtime, 예상 profile 결과,
   recovery 명령을 bootstrap 전에 보여주게 한다.
3. clean fixture와 의도적인 실패 fixture에서 bootstrap/doctor/contract를 실행한다.
4. 빈 또는 격리된 환경에서 설치하고, project 하나를 등록해 tmux/LazyVim 독립 경로와 Workbench
   복귀 경로를 각각 한 번 완주한다.
5. registry/config/lock backup을 만든 뒤 손상 fixture에서 복원한다. 실제 사용자 state를 파괴해
   시험하지 않는다.
6. 통과한 네 child commit과 검증 기록을 묶고, 실패 시 이전 조합으로 돌아가는 절차를 기록한다.
7. 최소 2주간 `setup`, `upgrade`, `resume`의 category-only 사용 기록을 남긴다.

**30일 완료 기준**

- 선택한 Tier-1 platform에서 fresh/isolated 시작부터 default-profile `doctor` healthy까지 2회 연속 성공.
- required/optional/disabled 결과가 profile 문서와 실제 exit code에서 일치.
- dirty child repo가 보존되고 해당 pull만 skip되는 실패 시험 통과.
- lock의 모든 commit이 동일 검증 run의 입력이며 drift가 명시적으로 실패 또는 경고로 구분됨.
- project 복귀는 terminal 독립 경로와 Workbench 경로 모두 성공하고, 한 경로 실패 시 수동 복구법이 있음.
- backup에서 config/registry를 복원하고 doctor가 다시 같은 결과를 냄.
- 실패 로그에 Secret plaintext, credential, 개인 command 전문이 없음을 수동 검토.

### 31~90일 — 반복 사용과 한정 통합

**목표:** 실제 사용 근거로 복귀 흐름을 다듬고, 두 번째 platform 및 첫 외부 연동의 경계를 검증한다.

1. 30일 사용 기록에서 가장 잦은 복귀 마찰 **상위 1개만** 개선한다.
2. 두 번째 platform 후보는 WSL을 우선 검토하고, macOS+tmux와 macOS+cmux는 별도 tier로 취급한다.
   실제 주 사용 빈도와 장비 접근성에 따라 순서는 바꿀 수 있다.
3. source-of-truth 표를 root 설치 문서, child 구현 문서, 제품 결정 문서에 적용하고 중복 설명을 링크로
   치환한다.
4. 검증 조합에 tag/release candidate와 rollback 절차를 붙인다. 공개 배포는 필수가 아니다.
5. MCP inventory를 읽기 전용으로 작성한다: client, scope, config owner/path 유형, transport, server
   provenance/version, credential **reference 유형**, health 방법, disable/rollback 방법. 값은 수집하지 않는다.
6. 사용자가 실제로 매주 쓰는 server 하나가 있을 때만, 임시 디렉터리에서 Codex·Claude 두 client 대상
   설정을 `dry-run → diff → explicit apply → health → rollback` 순서로 실험한다.
7. fallback 정리는 30일 이상 대표 사용에서 primary 성공이 확인된 항목 하나만 판정한다.

**90일 완료 기준**

- Tier-1은 월 1회 재현 smoke와 실제 사용 중 실패 0건, 또는 실패마다 검증된 복구 기록을 보유.
- 두 번째 platform은 최소 2회 fresh smoke를 통과했을 때만 experimental/support tier를 얻음.
- 상위 복귀 마찰 1개의 중간값 또는 단계 수가 baseline 대비 30% 이상 감소.
- 문서 진입점에서 5분 안에 현재 지원 tier, 검증 조합, 복구 절차를 찾는 self-review 통과.
- MCP 실험은 원본 client config byte-for-byte backup, owned block 또는 별도 include, Secret reference만 사용,
  두 client health, disable, 원복 후 동일성 확인을 모두 충족. 하나라도 없으면 기능 승격 금지.
- compatibility 제거는 fallback 미사용 기록과 관련 회귀 test, rollback commit이 모두 있을 때만 허용.

### 장기 — 증거가 생긴 영역만 확장

장기는 날짜가 아니라 진입 조건으로 관리한다.

- **Platform 확장:** macOS+tmux, macOS+cmux, native Windows를 각각 별도 제품 tier로 인증한다.
- **개인 업무 통합:** 문서·계획·반복 업무는 실제 API/파일/Git/webhook 흐름이 주 1회 이상 반복되고,
  수동 단계가 측정됐을 때 하나씩 추가한다. MCP 사용을 강제하지 않는다.
- **MCP 관리:** 두 개 이상의 server와 두 client에서 같은 catalog/config/health 계약이 반복될 때만
  Workbench registry 후보로 승격한다. lifecycle/update와 원격 OAuth는 별도 security review를 거친다.
- **UI 확장:** Dashboard가 대표 사용 기간 동안 실제 복귀 기본 경로가 되었을 때만 client mutation을
  늘린다. terminal fallback은 계속 유지한다.
- **배포:** 세 번 이상의 검증 조합 갱신에서 release/tag 절차가 반복될 때 자동화를 검토한다.

**장기 완료 기준**

- 새 기능마다 owner, local data schema, export/backup, migration, disable, rollback, offline degradation이 문서화됨.
- 외부 서비스 장애나 client 제거 후에도 핵심 terminal과 로컬 state read 경로가 동작함.
- Secret은 값이 아니라 reference와 availability metadata만 공통 계층을 통과함.
- 지원 tier 표시는 최근 실제 장비 smoke 날짜와 artifact에 연결되고, 90일 이상 미검증이면 자동으로
  “검증 만료”로 낮춤.

## 6. 검증 실험과 명시적 판정 기준

| 실험 | 방법 | 성공 기준 | 중단·피벗 기준 |
|---|---|---|---|
| Profile 분리 | 같은 fixture에 `terminal`/`workbench` 실행 | Workbench toolchain 부재가 terminal 성공을 막지 않고 workbench profile은 명확히 실패 | 예외 분기가 platform마다 달라지면 두 profile 대신 단일 required+명시적 `--without` 재검토 |
| Fresh bootstrap | 격리 HOME/fixture와 실제 Tier-1 장비 각 2회 | 멱등, 문서와 selection/exit 일치, 사용자 변경 보존 | 복구에 수동 파일 삭제나 force Git이 필요하면 기능 추가 중단 후 bootstrap 계약 수정 |
| Backup 복원 | synthetic registry/config를 손상 후 복구 | 사전 backup에서 복원, schema validate와 doctor 동일 | backup이 부분 파일만 담거나 Windows 비원자 교체에 취약하면 platform tier 승격 중단 |
| 복귀 관찰 | 2~4주 category-only 수동/로컬 기록 | 가장 잦은 primary와 fallback, 실패 원인 식별 | 표본 10회 미만이면 삭제·대규모 UI 투자 판단 금지; 수집이 번거로우면 자동화보다 표본 기간 연장 |
| Dashboard 기본 경로 | 동일 project 복귀를 CLI/tmux와 Dashboard로 비교 | 주간 복귀의 50% 이상 자발적 사용, 단계/시간 30% 개선 | 브라우저/server 문제로 fallback이 20% 넘거나 개선이 없으면 ops 보조 UI로 고정 |
| MCP inventory | 두 client 설정을 read-only로 비교 | owner/scope/transport/credential/rollback 필드 100% 채움 | Secret 값 열람·복제나 client 내부 파일 추측이 필요하면 즉시 중단, client 공식 CLI/API만 사용 |
| MCP config 생성 | 한 server, 두 client, 임시 config | deterministic diff, explicit apply, health, disable, byte-identical rollback | 한 client라도 config merge/rollback이 불안정하거나 credential 평문화가 필요하면 generator 폐기, 문서형 catalog로 피벗 |
| Worktree client | 기존 CLI 대비 UI/thin client prototype | 월 4회 이상 사용하고 안전 확인 단계 유지 | 사용 4주간 3회 미만 또는 ownership 재검증 우회 필요 시 보류 |
| Compatibility 축소 | 한 fallback에 warning/shim 관찰 | 30일 primary 성공, fallback 0, 회귀 test와 rollback 준비 | fallback 1회라도 실제 복구에 필요하거나 다른 장비 표본이 없으면 유지 |

## 7. 주요 리스크와 통제

| 리스크 | 반대 증거·제약 | 통제 |
|---|---|---|
| Workbench 중심화가 독립 terminal 경로를 막음 | 현 설계는 독립 경로를 의도하지만 profile은 required | profile 분리, 독립 경로 smoke를 release gate로 지정 |
| lock이 최신성 경쟁으로 변함 | 현재 report-only drift는 최신 HEAD와 검증 조합을 혼동하게 함 | 자동 갱신 금지, 검증 run ID·날짜·commit·rollback을 함께 기록 |
| 실제 장비 부족으로 지원을 과장 | cross-build/fake E2E는 runtime 증거가 아님 | build target, experimental, Tier-1을 문구와 exit contract에서 분리 |
| 사용 근거 수집이 감시로 변함 | 개인용이라 중앙 telemetry 이득이 작음 | local-only, opt-in, category/status/time만, export·삭제 가능, command/path/value 금지 |
| MCP local server가 임의 코드 실행 통로가 됨 | 공식 보안 지침도 local server가 client 권한으로 실행되는 위험을 명시 | allowlist, provenance/version pin, stdio 우선, sandbox, explicit enable, install 자동화 보류 |
| client 설정 생성이 사용자 설정을 덮음 | client마다 scope와 precedence가 다름 | dry-run/diff, owned block 또는 include, backup, compare-and-swap, byte-identical rollback |
| proxy가 credential·감사 단일 실패점이 됨 | OAuth/resource audience, SSRF, session 등 별도 공격면 존재 | 범용 proxy 보류, client native auth 유지, remote 연결은 별도 threat model |
| Secret redaction을 sandbox로 오해 | 현재 Workbench도 변형·파일·network 유출을 막지 않는다고 명시 | Secret 주입은 opt-in, trusted code 가정 표시, 고위험 workflow 제외 |
| 문서 정리가 구현 근거를 덮음 | child 문서가 세부 계약의 최종 근거 | plan에는 결정·tier·성공 기준만 두고 세부 명령은 링크 |

## 핵심 결론

현재 제품은 기능 부족 단계가 아니라 **신뢰성·지원 범위·사용 근거를 닫아야 하는 단계**다. 30일 MVP는
새 통합을 만드는 것이 아니라 한 platform/profile에서 fresh setup, update, resume, backup restore를
반복 가능하게 증명하고 그때의 child commit 조합을 재현 가능한 기준선으로 고정하는 것이다.

MCP는 중요한 장기 수단이지만 제품의 중심이나 유일한 연동 방식이 아니다. 첫 90일에는 Secret 값을
수집하지 않는 inventory와, 사용 중인 server 한 개를 두 client에 가역적으로 연결하는 실험까지만 허용한다.

## 채택 권고

1. **즉시 채택:** profile별 Workbench 정책, 단일 Tier-1, 검증 조합 lock, prerequisite preflight,
   fresh/restore runbook, category-only 사용 기록.
2. **30일 기능 동결:** 기존 Workbench 기능은 유지하되 새 Dashboard/backend/MCP lifecycle 구현을 시작하지 않는다.
3. **90일 조건부 채택:** 실제 사용 상위 마찰 하나, 두 번째 platform smoke, 문서 owner 정리, release/rollback,
   read-only MCP inventory.
4. **실험으로만 허용:** MCP 1→2 client 생성기, Dashboard 기본 경로, worktree UI, cmux 자동 동기화.
5. **명시적 보류:** native Windows 전체 지원, 공통 backend lifecycle, 범용 MCP proxy/plugin framework,
   cloud sync와 multi-user control plane.

## 반론

- **“이미 기능이 많으니 바로 개인 업무 통합을 시작해야 한다.”** 통합 하나를 실제 업무에서 사용하면
  방향 학습이 빠르다는 장점이 있다. 다만 현재도 지원 정책·lock·실장비 증거가 어긋나므로, 먼저 30일
  신뢰성 gate를 통과하지 않으면 새 통합 실패가 기반 문제인지 외부 서비스 문제인지 구분하기 어렵다.
- **“Workbench를 optional로 만들면 제품 메시지가 약해진다.”** 모든 profile에서 required로 두면 단일
  경험은 선명해진다. 반대로 Go/toolchain 문제 하나가 terminal 복구 전체를 실패시키므로 local-first와
  장애 독립성이 약해진다. `terminal`과 `workbench` profile은 이를 사용 목적에 따라 명시적으로 나눈다.
- **“MCP control plane을 먼저 만들면 Codex·Claude 설정 중복이 곧바로 줄어든다.”** 가능한 이득이다.
  그러나 client scope, native CLI, auth, config merge가 다르고 local MCP server 자체가 실행 권한을 가진다.
  한 server/두 client 실험에서 공통 계약이 실제로 반복되는지 확인한 뒤 추상화하는 편이 되돌리기 쉽다.
- **“점수가 높은 문서 정리를 핵심에서 뺀 것은 모순이다.”** 문서 정리는 85점으로 중요하지만 신뢰성
  MVP의 선행조건은 아니다. 30일에는 결정·runbook에 필요한 최소 문서만 고치고, 중복 축소는 증명된
  계약을 기준으로 90일까지 수행한다.

## 불확실성

- 실제 primary 장비와 주간 사용 패턴이 기록되지 않아 Linux와 WSL 중 첫 Tier-1 선택은 확정할 수 없다.
- Workbench/Dashboard, `bb`, LazyVim 중 어느 복귀 경로가 실제 primary인지 표본이 없다.
- MCP 대상 client 버전, server 종류, config 위치·scope, 인증 방식, 실제 사용 빈도가 inventory 전이다.
- 현재 검증은 2026-08-10 snapshot이며 child repository HEAD나 외부 client 계약이 이후 바뀔 수 있다.
- 점수는 상대 비교를 위한 정성 추정이다. 30일 사용 기록 뒤 V/F/O 점수를 다시 매기면 분류가 바뀔 수 있다.
- 실제 macOS, WSL, native Windows 장비 접근 가능성과 smoke 자동화 비용은 확인되지 않았다.

## 출처

### 저장소 내부 근거

- [root README](../../README.md), [DEPENDENCIES](../../DEPENDENCIES.md),
  [제품 기획](../PRODUCT-PLAN.md) — 제품 구조, 설치·업데이트 계약, 미결정. 확인일 2026-08-10.
- [현재 시스템](current-system.md), [저장소 기준선](repository-baseline.md),
  [검증 기준선](validation-baseline.md), [후보 과제](backlog-and-open-questions.md) — 구현 기능,
  lock/profile 충돌, 검증 공백, 후보 backlog. 확인일 2026-08-10.
- [Workbench README](../../workbench/README.md),
  [backend contract](../../workbench/docs/backend-contract.md),
  [worktree 안전 계약](../../workbench/docs/worktrees.md),
  [Secret 경계](../../workbench/docs/secrets.md),
  [Dashboard 보안](../../workbench/docs/dashboard.md),
  [typed workflow](../../workbench/docs/workflows.md) — local state, ownership 재검증, backup,
  임의 실행 제한, Secret redaction의 한계. 확인일 2026-08-10.

### 공식·1차 외부 근거

- [MCP 2025-11-25 Authorization specification](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) —
  HTTP authorization, resource audience, discovery, scope 최소화 요구. 확인일 2026-08-10.
- [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices) —
  confused deputy, SSRF, session hijacking, local server compromise와 최소 권한 통제. 확인일 2026-08-10.
- [MCP SEP-1024: Local Server Installation Security Requirements](https://modelcontextprotocol.io/seps/1024-mcp-client-security-requirements-for-local-server-) —
  local server 설치 흐름의 임의 명령 실행 위험과 client 측 통제 필요. 확인일 2026-08-10.
- [Anthropic Claude Code MCP documentation](https://docs.anthropic.com/en/docs/claude-code/mcp) —
  local/project/user scope, client native 관리·인증 경로의 근거. 확인일 2026-08-10.
- [Git `git-worktree` documentation](https://git-scm.com/docs/git-worktree.html) —
  porcelain 형식, clean/locked worktree remove 안전 조건, repair/lock 동작. 확인일 2026-08-10.
