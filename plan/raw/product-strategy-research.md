# Setup 제품 전략 및 목표 검증

> 조사일: 2026-08-10
>
> 범위: 개인 환경과 업무를 함께 관리하는 local-first 개인 운영 환경
>
> 근거: root/child 저장소의 현행 문서와 코드 기준선, 공식 제품 문서·표준
>
> 표기: **[사실]** 관찰·문서로 확인, **[추론]** 사실에서 도출한 판단, **[제안]** 채택 여부를 결정할 제품 선택

## 1. 조사 질문과 판단 기준

이 조사는 “Workbench에 무엇을 더 넣을까”가 아니라 다음 네 질문을 검증한다.

1. 사용자가 실제로 반복해서 겪는 상위 문제는 무엇인가?
2. 어느 책임을 Setup이 직접 소유해야 하고, 어느 책임은 기존 도구에 위임해야 하는가?
3. local-first·사용자 통제·보안·복구 가능성·서비스 비종속성을 제품 구조로 어떻게 보장할 것인가?
4. 기능 확장이 가치를 더하는 시점과 범위 폭발을 일으키는 시점을 어떻게 구분할 것인가?

평가 기준은 다음과 같다.

| 기준 | 확인 질문 |
|---|---|
| 반복 가치 | 적어도 주 단위로 발생하며 준비·복귀·복구 시간을 줄이는가? |
| 소유권 | 원본 데이터와 실제 실행 주체가 명확한가? |
| 독립성 | Workbench나 외부 서비스가 없어도 핵심 작업과 복구가 가능한가? |
| 가역성 | 변경 전 검토, backup, rollback 또는 수동 복구 경로가 있는가? |
| 이식성 | 파일·Git·공개 API 같은 교체 가능한 계약을 우선하는가? |
| 증거 | 실제 장비와 대표 흐름으로 지원 수준을 입증했는가? |
| 유지 비용 | 새 기능이 장기적으로 늘리는 adapter·schema·보안·문서 비용을 감당할 수 있는가? |

## 2. 핵심 문제의 재정의

### 2.1 현재 문제는 도구 부족이 아니라 운영 맥락의 단절이다

**[사실]** 현재 시스템은 이미 설치·업데이트·doctor, terminal workspace, 편집, 인프라 명령,
project/environment/session/worktree/Agent 상태, Dashboard, Secret, backend 실행을 다섯 저장소에 걸쳐 제공한다.
따라서 “개인 생산성 기능이 부족하다”는 설명은 현재 구현을 제대로 설명하지 못한다.

**[사실]** 프로젝트, Git worktree, tmux pane/session, Agent, 환경 변수, Secret, 업무 서비스 상태는 서로 다른
도구가 소유한다. Workbench는 일부를 정규화하지만 tmux·Git·외부 process의 실체까지 소유하지 않으며,
그 경계를 의도적으로 유지한다.

**[추론]** 상위 문제는 다음과 같다.

> 개인의 의도와 작업 맥락이 장비·프로젝트·도구·서비스 사이에 흩어져 있어, “무엇을 하던 중이었고,
> 지금 무엇이 안전하게 가능하며, 실패하면 어떻게 되돌아가는가”를 매번 다시 조립해야 한다.

이 문제는 네 가지 비용으로 나타난다.

| 비용 | 사용자 질문 | 현재 증거 |
|---|---|---|
| 준비 비용 | 이 장비에서 무엇이 설치·연결·검증됐는가? | platform profile, prerequisite, lock 의미가 아직 완전히 정렬되지 않음 |
| 복귀 비용 | 어떤 프로젝트·worktree·session·Agent로 돌아가야 하는가? | Workbench가 일부 제공하지만 실제 일상 사용 근거는 부족 |
| 통합 비용 | 문서·계획·업무 서비스·개발 도구를 어떤 권한으로 연결했는가? | MCP/client/Secret inventory가 아직 없음 |
| 복구 비용 | 자동화 실패 또는 core 장애 때 무엇을 신뢰하고 어떻게 되돌리는가? | 독립 terminal 경로는 설계됐으나 Workbench required 정책과 충돌 |

### 2.2 제품이 해결해야 할 Job

**[제안]** Setup이 소유할 핵심 Job은 기능 범주가 아니라 하나의 반복 루프로 정의한다.

> **준비한다 → 맥락을 복원한다 → 제한된 행동을 실행한다 → 결과와 실패를 설명한다 → 원본 도구로 복구한다.**

이 루프에서 Setup은 모든 데이터를 흡수하는 중앙 앱이 아니라 다음 역할을 맡는다.

- 선언된 환경과 통합을 장비에 재현한다.
- 여러 원본의 상태를 읽어 “지금의 작업 맥락”을 구성한다.
- 위험이 낮고 계약이 명확한 행동만 typed action으로 제공한다.
- 실패 원인, 소유자, 마지막 성공 상태, 수동 복구 경로를 보존한다.
- 외부 서비스나 Workbench가 없어도 원본 파일·Git·CLI로 빠져나갈 수 있게 한다.

### 2.3 해결하지 말아야 할 가짜 문제

**[추론]** 다음 목표는 매력적이지만 핵심 문제의 해법이 아니다.

- 모든 앱의 데이터를 하나의 database에 복제하는 것
- 모든 명령을 하나의 UI에서 실행하는 것
- MCP server 수나 integration 수를 늘리는 것
- terminal, editor, 문서 도구, workflow engine을 자체 구현으로 대체하는 것
- macOS·Linux·WSL·native Windows의 기능 수를 처음부터 동일하게 맞추는 것

이들은 표면적 통합감을 높일 수 있지만 source of truth 중복, 권한 확대, adapter 유지 비용과 복구 불확실성을
동시에 키운다.

## 3. 현재 제품 방향 검증

### 3.1 이미 강한 기반

**[사실]** 다음 안전·복구 계약은 제안하는 개인 운영 환경과 잘 맞는다.

- root update는 추적 변경이 있으면 건너뛰고 fast-forward only로 동작한다.
- tmux와 Git이 실제 lifecycle의 source of truth이고, Workbench는 소유를 증명한 대상만 변경한다.
- 외부 worktree와 observed task는 보이되 삭제·stop 권한을 얻지 않는다.
- Dashboard는 loopback, process token, origin/body 제한과 allowlisted typed action을 사용한다.
- Secret 평문은 argument·JSON 목록·Dashboard snapshot으로 노출하지 않고 암호화 저장과 backup을 사용한다.
- registry mutation은 backup과 검증을 거치며, partial failure에서 살아남은 자원을 숨기지 않는다.
- Workbench 없이 tmux·LazyVim·binbox를 쓰는 독립 경로가 설계되어 있다.

**[추론]** 이 프로젝트의 가장 가치 있는 자산은 Dashboard 화면이나 명령 개수가 아니라 이미 구현된
“관찰과 소유의 분리”, “실패를 숨기지 않는 계약”, “독립 복구 경로”다. 향후 문서·계획·자동화·외부 서비스
통합도 같은 계약을 통과해야 한다.

### 3.2 아직 제품 주장으로 확정하기 어려운 부분

**[사실]** Workbench는 문서상 독립 terminal 경로를 보존하는 optional core로 설명되지만 현재 Linux,
macOS, WSL profile에서는 required다. native Windows는 Workbench build target이지만 root provisioning
profile이 없다. 실제 macOS/cmux, Windows/WSL 전체 흐름과 장기간 server/scheduler는 현재 기준선에서
증명되지 않았다.

**[사실]** lock snapshot은 4개 child 중 3개가 현재 HEAD와 다르며 report-only다. 따라서 지금 상태에서
“검증된 조합을 재현한다”는 문구는 lock을 release manifest처럼 해석하면 과장이다.

**[추론]** 현재 구현은 “개인 개발환경 운영 콘솔”의 좋은 기반이지만 “업무 전반의 통합 운영 환경”은
아직 방향 가설이다. 문서·계획·정보 수집·반복 업무의 대표 흐름과 첫 외부 서비스 통합을 검증하기 전에는
제품 정의와 구현 범위를 구분해야 한다.

## 4. 유사 제품·접근법이 주는 시사점

비교의 목적은 기능 수나 시장 순위를 매기는 것이 아니라 Setup이 직접 만들 책임과 위임할 책임을 찾는 데 있다.

### 4.1 chezmoi — 장비 재현은 독립 제품 범주다

**[사실]** chezmoi는 여러 OS·계정의 dotfile을 단일 source state와 machine-local config로 관리하며,
template, dry-run/diff, encryption, password manager 연동, 원자적 적용과 일반 파일 기반의 이탈 가능성을
강조한다. 단일 정적 binary로 배포되어 bootstrap prerequisite도 작다.

**[추론]** Setup의 root orchestration은 여러 독립 저장소의 설치 순서와 계약 검증이라는 고유 책임이 있지만,
dotfile templating·충돌 처리·비밀 관리자 연동 같은 성숙한 문제를 전부 다시 구현할 이유는 약하다. 특히 현재
Go toolchain prerequisite 때문에 Workbench 설치가 전체 bootstrap 실패가 될 수 있는 구조는 “복구 환경은
가장 작은 의존성으로 시작해야 한다”는 시사점과 반대 방향이다.

**[제안]** root setup은 repo/profile/compatibility orchestration에 집중하고, 파일 배포 기능을 확장하기 전에
chezmoi 같은 기존 도구에 위임 가능한지 평가한다. 어떤 구현을 쓰든 `plan/diff → explicit apply → backup →
rollback` 계약은 채택한다.

### 4.2 Nix Home Manager — 선언성과 재현성의 상한, 복잡성의 경고

**[사실]** Home Manager는 사용자 package와 설정을 선언적으로 구성하고, NixOS module 또는 독립 방식으로
활성화한다. 호환성 경계로 `home.stateVersion`을 사용하며 기존 파일 충돌 시 backup 또는 실패 정책도 제공한다.

**[추론]** 검증된 lock과 선언적 profile은 Setup에 유용하지만, 개인 업무 상태와 살아 있는 terminal/Agent
맥락까지 Nix-style desired state로 환원하면 소유권과 런타임 현실을 잃는다. 또한 Nix 채택 자체가 macOS·WSL의
초기 진입 비용과 새로운 복구 지식을 요구한다.

**[제안]** “모든 것을 Nix로”가 아니라 versioned manifest, profile별 선택, migration과 rollback만 차용한다.
runtime 관찰 상태는 선언 파일과 분리한다.

### 4.3 Dev Container Specification — 프로젝트 환경과 개인 운영 환경의 경계

**[사실]** Development Containers는 개발 전용 container에 설정과 content를 더하는 공개 specification이며,
여러 도구와 서비스가 같은 정의를 지원할 수 있도록 설계됐다.

**[추론]** devcontainer는 프로젝트별 toolchain 재현과 격리에 강하지만 host terminal, 개인 문서, 여러 project
간 우선순위, 장시간 Agent 복귀, 외부 업무 서비스 연결을 대신하지 않는다. 반대로 Setup이 project toolchain을
자체 package manager로 소유할 필요도 없다.

**[제안]** devcontainer를 향후 project capability/provider로 관찰할 수는 있지만 container lifecycle을 core
기능으로 재구현하지 않는다. Setup은 “어떤 project가 어떤 실행 surface를 쓰는가”와 진입·health만 소유한다.

### 4.4 Obsidian — 문서·계획은 열린 로컬 파일이 가장 강한 탈출구다

**[사실]** Obsidian은 데이터를 기기에 저장하고 Markdown 같은 단순한 공개 파일 형식으로 lock-in을 줄이는 것을
제품 원칙으로 명시한다. URI는 open/new/search 같은 제한된 cross-app action을 제공한다.

**[추론]** 개인 운영 환경의 문서·계획·수집 정보는 Workbench database에만 저장하면 검색 UI는 편해져도 장기
복구성과 서비스 비종속성이 약해진다. 반대로 Markdown 원본과 안정된 link/metadata 규칙을 사용하면 Git,
editor, CLI, 다른 문서 도구가 동시에 접근할 수 있다.

**[제안]** 문서·계획의 canonical data는 사용자가 고른 로컬 폴더의 Markdown/첨부 파일로 둔다. Workbench는
index, backlink/context projection, open/capture 같은 제한된 action만 제공하고 전용 editor나 독점 schema를
만들지 않는다. Obsidian 자체도 optional client이지 필수 runtime은 아니다.

### 4.5 n8n — 범용 자동화의 가치와 blast radius

**[사실]** n8n은 API를 가진 앱을 workflow로 연결하고 self-host 선택을 제공한다. 동시에 공식 security audit은
host filesystem 접근, code 실행, community/custom node, 공개 webhook을 위험 항목으로 다룬다. Git 기반 환경
기능에서도 양방향 push/pull이 덮어쓰기와 데이터 손실을 일으킬 수 있어 단방향 흐름을 권고하며, source-control
환경 같은 일부 기능은 유료 tier에 속한다.

**[추론]** 범용 workflow canvas와 arbitrary command runner를 Workbench에 넣으면 외부 서비스 credential,
webhook 노출, scheduler, retry, execution history, plugin 공급망을 모두 새로 소유하게 된다. 이는 현재 typed
allowlist와 최소 권한 모델을 무너뜨릴 가능성이 높다.

**[제안]** 반복 업무 자동화는 우선 Git에 저장된 작은 script/runbook, OS scheduler, GitHub Actions 또는
self-host workflow engine에 위임한다. Setup은 enable/disable, Secret reference, health, last result, 수동 재실행
경로를 정규화하되 workflow engine 자체가 되지 않는다.

### 4.6 Home Assistant — local control과 integration 품질 등급의 모델

**[사실]** Home Assistant는 local control과 privacy를 우선하고 인터넷이 끊겨도 로컬 데이터와 제어가 동작하는
것을 제품 가치로 둔다. 공식 Integration Quality Scale은 setup, test, 오류 복구, owner, diagnostics,
documentation 등을 누적 tier로 평가하며, custom integration은 core가 security·stability를 보증하지 않는다고
명시한다.

**[추론]** 수많은 외부 서비스를 “지원/미지원” 이진값으로 관리하면 Setup도 지원 과장과 유지보수 부채를 겪는다.
현재 platform claim 문제와 같은 유형이다. integration마다 owner, permissions, data direction, health, tested
platform, rollback 수준을 표현하는 등급이 필요하다.

**[제안]** 서비스별 adapter manifest와 증거 기반 maturity tier를 도입한다. 예시는 다음과 같다.

| tier | 의미 | 최소 증거 |
|---|---|---|
| Experimental | 개인 실험, 지원 주장 없음 | 수동 연결과 제거 절차 |
| Observed | 읽기/health만 제공 | fixture test, 오류 노출, Secret 비노출 |
| Managed | 제한된 쓰기 제공 | typed action, backup/dry-run, 실제 장비 smoke, rollback |
| Trusted | 일상 기본 경로 후보 | 장기간 사용, 장애 복구 기록, 명시적 owner와 호환 정책 |

### 4.7 MCP — 핵심 제품이 아니라 교체 가능한 transport/adapter

**[사실]** MCP 공식 architecture는 host가 client별 연결, permission, consent와 context aggregation을 관리하고,
server는 좁은 capability를 제공하는 구조다. MCP 자체는 AI application이 context를 어떻게 사용하거나 LLM을
어떻게 관리할지 정하지 않는다. 공식 보안 문서는 tool을 임의 코드 실행처럼 주의하고 명시적 동의, 최소 권한,
token audience 검증과 token passthrough 금지를 요구한다.

**[추론]** Setup이 거대한 MCP proxy가 되면 host가 가져야 할 승인·context 경계를 중복 소유하고 새로운
credential 집중점을 만든다. 또한 문서·계획·자동화·외부 서비스는 API, webhook, file, Git, CLI가 더 단순한
경우가 많다.

**[제안]** integration contract가 먼저이고 MCP는 그 contract의 한 adapter로 둔다. 동일 capability에 native
API나 파일 방식이 더 투명하고 복구 가능하면 그것을 우선한다. MCP 관리의 첫 단계는 catalog, client별 config
projection, handshake/health, Secret reference와 disable/rollback까지로 제한하고 tool 호출 proxy나 전체 로그
수집은 제외한다.

## 5. 차별화 가능성

### 5.1 차별화될 수 있는 지점

**[추론]** local-first, dotfile sync, terminal workspace, notes, automation, MCP catalog 각각은 이미 강한 제품이
있다. 그러므로 “이 기능도 있다”는 차별화가 아니다.

**[제안]** 차별화는 다음 결합에 둔다.

1. **개인 운영 맥락의 연결:** 장비 준비, project/worktree/session/Agent 복귀, 문서·계획의 관련 맥락,
   integration health를 한 read model에서 연결한다.
2. **원본 소유권 보존:** Git, tmux, 파일, 외부 API가 계속 source of truth이며 Setup은 검증된 projection과
   제한된 action만 제공한다.
3. **복구 독립성:** Dashboard, Workbench, MCP server, SaaS 하나가 실패해도 원본 CLI·파일과 기록된 복구
   절차로 작업을 계속한다.
4. **개인 정책의 코드화:** home/work, platform, risk, Secret scope와 confirmation 규칙을 profile로 재현한다.
5. **증거 기반 지원:** “연결됨”과 “안전하게 관리됨”을 구분하고 실제 장비·오류·rollback 증거를 공개한다.

이 조합은 대중 시장의 기능 moat라기보다 한 사용자의 실제 운영 규칙을 축적하는 **personal fit moat**다.
제품 성공도 경쟁 제품보다 기능이 많은지가 아니라, 사용자가 다시 판단해야 하는 횟수와 복구 시간이 줄었는지로
판정해야 한다.

### 5.2 차별화가 사라지는 조건

- Dashboard가 원본보다 먼저 수정되는 별도 database가 된다.
- Workbench 없이는 bootstrap 또는 기본 terminal 작업을 시작할 수 없다.
- integration 수가 늘지만 실제로 매일 쓰는 준비·복귀·복구 흐름은 개선되지 않는다.
- API·file 방식이 충분한데도 모든 연결을 MCP로 감싼다.
- 문서와 계획을 자체 포맷에 가두거나 export를 사후 기능으로 취급한다.
- platform·integration 지원을 test tier 없이 마케팅 문장으로 선언한다.

## 6. 실패 위험과 범위 확장 위험

| 위험 | 가능성 | 영향 | 조기 신호 | 통제/중단선 |
|---|---:|---:|---|---|
| 개인용 만능 플랫폼으로 범위 폭발 | 매우 높음 | 매우 큼 | 새 도메인이 기존 대표 흐름 없이 추가됨 | 분기당 한 핵심 흐름, 사용 증거 없으면 구현 금지 |
| source of truth 중복 | 높음 | 매우 큼 | 원본과 registry가 달라 어느 쪽을 고칠지 모름 | owner matrix 필수, projection 재생성 가능해야 함 |
| 중앙 core 장애가 전체 환경을 막음 | 중간 | 매우 큼 | Go/Workbench 실패로 bootstrap 전체 실패 | minimal profile, optional core, 독립 doctor/CLI 경로 |
| credential·권한 집중 | 높음 | 매우 큼 | 하나의 daemon이 여러 서비스 write token 보유 | scope별 reference, on-demand resolution, write opt-in |
| integration 유지보수 부채 | 높음 | 큼 | upstream 변경 때 health 없이 조용히 실패 | manifest/tier/owner/version, 사용하지 않으면 disable/remove |
| 자동화가 임의 실행기로 변질 | 중간 | 매우 큼 | browser/API가 command·argv·path를 자유 입력 | compiled/declared allowlist 유지, 외부 engine 위임 |
| local-first가 backup 부재를 가림 | 중간 | 큼 | 로컬 파일 손실이 곧 전체 손실 | 암호화 backup과 restore drill을 별도 성공 기준으로 둠 |
| multi-repo와 문서 drift | 높음 | 큼 | lock·README·profile이 서로 다른 사실을 주장 | release manifest owner, generated check, archive 분리 |
| UI 구축이 실제 사용보다 앞섬 | 높음 | 중간 | CLI/파일 흐름 미검증 상태에서 화면 추가 | 대표 흐름은 CLI/runbook으로 먼저 검증 |
| 1인 사용자 특화가 유지 불가능한 코드가 됨 | 중간 | 큼 | 예외가 profile이 아니라 분기문으로 누적 | 좁은 contract, adapter 격리, 삭제 비용을 설계에 포함 |

### 6.1 가장 위험한 범위 확장 순서

**[추론]** 다음 연결은 차례로 권한과 운영 책임을 확대한다.

`읽기/링크 → 상태/health → 설정 생성 → 제한된 쓰기 → scheduler/retry → arbitrary execution`

**[제안]** 새 domain은 항상 왼쪽에서 시작하고, 한 단계 오른쪽으로 갈 때마다 실제 사용 빈도, 실패 기록,
권한 모델, rollback test가 있어야 한다. “API가 제공된다” 또는 “MCP server가 있다”는 승격 근거가 아니다.

## 7. 제품 초점과 단계별 검증 가설

### 7.1 권고하는 첫 제품 쐐기

**[제안]** 향후 기능을 다음 세 가지 사용자 약속에 묶는다.

1. **Prepare:** 새 장비·새 project에서 필요한 환경, profile, integration 상태를 예측 가능하게 준비한다.
2. **Resume:** 마지막 작업의 project/worktree/session/Agent와 관련 문서·계획을 빠르게 다시 연다.
3. **Recover:** 실패한 owner와 원인을 보여주고 backup·원본 CLI·수동 runbook으로 되돌린다.

“Capture/Plan/Automate/Integrate”는 독립 모듈명이 아니라 이 세 약속을 강화할 때만 들어온다. 예를 들어 회의
메모 capture는 resume할 project와 연결되고 Markdown으로 남을 때 가치가 있으며, 반복 업무 자동화는 prepare나
recover 시간을 실제로 줄일 때 가치가 있다.

### 7.2 기능 채택 게이트

새 기능은 다음 질문에 모두 답해야 한다.

- 어떤 반복 Job의 시간을 줄이는가?
- canonical data와 mutation owner는 무엇인가?
- 최소 read-only slice는 무엇인가?
- 필요한 Secret과 외부 전송 데이터는 무엇인가?
- offline/서비스 장애 때 무엇이 동작하는가?
- disable, export, backup, rollback은 어떻게 하는가?
- 어떤 실제 platform에서 어떤 오류까지 검증했는가?
- 90일 쓰지 않으면 무엇을 안전하게 삭제할 수 있는가?

하나라도 답하지 못하면 research/backlog에 남기고 managed 기능으로 승격하지 않는다.

### 7.3 성공 지표

**[제안]** command 수나 integration 수 대신 로컬에 최소 metadata만 기록하거나 수동 관찰한다.

| 지표 | 측정 의도 |
|---|---|
| 빈 장비에서 usable terminal까지 걸린 시간 | Prepare 가치와 prerequisite 문제 |
| 작업 중단 후 정확한 surface로 복귀하는 시간 | Resume 가치 |
| Workbench를 끈 상태에서 기본 흐름 완주 여부 | 독립성 |
| 실패 원인과 owner를 찾는 시간 | diagnostics 가치 |
| backup에서 실제 복구한 대표 흐름 수 | 가역성의 실증 |
| primary/fallback 사용 비율과 실패 사유 | 제거·유지 판단 |
| integration별 최근 사용·최근 성공·permission tier | 유지할 adapter 선별 |

명령 내용, 문서 본문, Secret, prompt 전문은 기본 telemetry에 포함하지 않는다.

## 8. 한 문장 비전 후보

### 후보 A — 권고

**[제안]** **Setup은 내 데이터와 도구의 소유권을 지키면서, 어느 장비에서든 개인 업무와 개발 맥락을
안전하게 준비하고 이어가고 복구하는 local-first 운영 환경이다.**

- 장점: 개발환경을 기반으로 포함하되 최종 목적을 작업 연속성과 통제권으로 확장한다.
- 한계: “정보 수집·자동화·서비스 연결”이 문장에 직접 드러나지 않지만, 이들은 수단이므로 오히려 범위를 지킨다.

### 후보 B — 더 구체적

**[제안]** Setup은 파일·Git·terminal·외부 서비스를 하나의 복구 가능한 개인 작업 맥락으로 연결하는
terminal-first 운영 도구다.

- 장점: 연결 대상과 terminal 정체성이 선명하다.
- 한계: 장기적으로 GUI나 mobile capture가 중요해질 경우 표현이 좁다.

### 후보 C — 더 짧음

**[제안]** 내 일과 개발을 어디서나 이어가게 하는, 내가 통제하는 개인 운영 환경.

- 장점: 기억하기 쉽고 기술에 종속되지 않는다.
- 한계: 안전·복구·local-first의 차별점이 약하다.

## 9. 제품 원칙

1. **Local source of truth by default.** 문서·계획·설정·상태는 가능한 한 로컬의 읽을 수 있는 파일과 Git에 둔다.
2. **한 domain, 한 owner.** Setup은 원본을 복제해 새 진실을 만들지 않고 owner의 상태를 projection한다.
3. **Observe before manage.** 먼저 읽기와 health를 제공하고, 소유권과 rollback이 증명된 뒤에만 쓰기를 연다.
4. **Explicit authority.** 위험한 변경, 외부 전송, 권한 확대는 typed input과 명시적 확인을 요구한다.
5. **Graceful degradation.** Workbench, Dashboard, adapter, SaaS 하나의 실패가 기본 terminal·파일 흐름을 막지 않는다.
6. **Reversible by construction.** diff/dry-run, backup, migration, disable, export, rollback을 기능 정의에 포함한다.
7. **Open contracts over centralization.** 파일, Git, 공개 API, webhook, CLI, MCP 중 가장 단순하고 이식 가능한 계약을 쓴다.
8. **Secrets are references, not content.** 평문을 registry·문서·log·Dashboard에 복제하지 않고 필요한 순간 최소 scope로 해석한다.
9. **Evidence earns support.** platform과 integration 지원 수준은 실제 장비, 오류, 복구 test의 수준으로 표현한다.
10. **Automate proven repetition.** 반복 횟수와 수동 runbook이 확인되기 전에는 범용 추상화나 scheduler를 만들지 않는다.
11. **Small core, replaceable edges.** core는 identity, policy, context, health, recovery contract에 집중하고 client/provider는 교체 가능하게 둔다.
12. **Deletion is a feature.** 사용하지 않는 adapter와 generated state를 원본 손실 없이 제거할 수 있어야 한다.

## 10. 비목표

- 범용 IDE, terminal emulator, editor 또는 note-taking 앱을 자체 대체하지 않는다.
- 모든 개인 정보와 업무 데이터를 하나의 중앙 database에 수집하지 않는다.
- 범용 GTD/project management 방법론이나 team collaboration suite가 되지 않는다.
- 상시 cloud account, proprietary sync 또는 multi-user control plane을 필수로 하지 않는다.
- 임의 command를 browser/API에서 실행하는 범용 automation engine이 되지 않는다.
- 모든 API·webhook·file 연동을 MCP로 변환하거나 모든 MCP tool 호출을 중계하지 않는다.
- 모든 Secret의 중앙 vault나 조직용 IAM을 구현하지 않는다.
- 모든 OS와 client의 기능 parity를 초기에 약속하지 않는다.
- 외부 서비스의 데이터를 “편의를 위해” 무단 복제하거나 영구 보관하지 않는다.
- integration 수, Dashboard 화면 수, command 수를 제품 성공으로 보지 않는다.
- 성숙한 dotfile manager, container runtime, workflow engine의 일반 기능을 근거 없이 재구현하지 않는다.

## 11. 핵심 결론

1. **[추론]** 제품이 해결할 핵심 문제는 앱 부족이 아니라 개인 작업 맥락과 통제·복구 정보가 도구와 장비 사이에서
   단절되는 문제다.
2. **[사실]** 현재 구현의 가장 강한 차별 자산은 관찰/소유 분리, typed action, 실패 투명성, backup과 독립
   terminal 경계다. 이 계약을 문서·계획·자동화·서비스 integration에도 확장해야 한다.
3. **[추론]** 시장의 기존 제품은 재현, 문서, 자동화, integration 각각을 더 깊게 해결한다. Setup은 이들을
   대체하기보다 개인의 Prepare–Resume–Recover 루프로 안전하게 조합할 때 차별화된다.
4. **[추론]** 가장 큰 실패 위험은 기술 난도가 아니라 범위 폭발과 source of truth 중복이다. 특히 범용 automation,
   중앙 credential, 독점 문서 schema, 거대 MCP proxy는 현재 원칙과 충돌한다.
5. **[사실]** 업무 전반의 통합 운영 환경은 아직 검증된 현재 기능이 아니라 방향 가설이다. 실제 대표 업무 흐름과
   첫 외부 integration을 좁게 검증한 뒤 제품 주장을 승격해야 한다.

## 12. 채택 권고

1. 비전 후보 A를 제품 비전으로 채택하고, “나만의 통합 도구”를 **모든 기능의 내장**이 아니라 **내 소유권 아래의
   작업 맥락 연결**로 정의한다.
2. 첫 제품 쐐기를 Prepare–Resume–Recover로 고정한다. 새 domain은 이 셋 중 하나의 측정 가능한 비용을 줄여야 한다.
3. Workbench를 profile별 구성요소로 만들고 minimal terminal profile에서는 optional로 두는 방향을 우선 검증한다.
   core 장애 상태의 대표 여정을 성공 기준에 포함한다.
4. lock snapshot은 “검증된 release manifest” 또는 “관찰 snapshot” 중 하나로 명확히 선택한다. 전자를 택하면 갱신
   command, 실제 장비 evidence, rollback commit을 함께 기록한다.
5. 문서·계획의 canonical format은 로컬 Markdown/첨부 파일로 두고 Workbench는 index·context·open/capture만 제공한다.
6. 첫 외부 서비스 integration은 단 하나를 골라 `Observed → Managed` 순으로 진행한다. transport는 API/webhook/file/
   Git/MCP 중 가장 단순한 것을 선택하고, Secret reference·disable·rollback을 먼저 설계한다.
7. integration manifest에 owner, data direction, permission scope, transport, tested platform, maturity tier, last health,
   removal/rollback을 기록한다.
8. 범용 workflow engine과 MCP proxy는 만들지 않는다. 반복 workflow가 필요하면 기존 engine이나 versioned script를
   adapter로 연결하고 Workbench는 health와 제한된 trigger만 소유한다.
9. platform과 integration의 지원 표현을 evidence tier로 바꾸고, cross-build·fixture·실제 장비 smoke를 구분한다.
10. 다음 기능 기획 전에 최소 2~4주의 대표 일상 흐름 관찰로 복귀 시간, fallback, 실패·복구 사례를 raw 자료에 남긴다.

## 13. 반론

### 반론 1: 한 사람이 쓰는 도구인데 범위를 좁히면 통합의 이점이 사라진다

그럴 수 있다. 개인 도구는 일반 시장 제품보다 사용자 특화 예외를 더 잘 수용할 수 있다. 다만 통합의 이점은 한
binary나 database에 모으는 데서만 나오지 않는다. 공통 identity, link, policy, health, recovery contract만으로도
원본 도구를 유지한 채 상당한 연결 가치를 얻을 수 있다. 좁은 core는 확장을 금지하는 것이 아니라 실패 반경을
제한한다.

### 반론 2: 이미 Workbench가 많은 기능을 구현했으니 중심 IDE로 밀어야 한다

현재 Dashboard와 state core는 실질적 자산이다. 그러나 실제 일상 기본 경로라는 사용 근거와 물리 장비 evidence가
부족하다. 먼저 ops/resume console로 신뢰도를 증명한 뒤 사용 빈도가 높으면 중심성을 높이는 편이 되돌리기 쉽다.

### 반론 3: MCP 하나로 통일하면 client별 adapter 비용이 줄어든다

MCP가 공통 discovery와 tool/resource contract를 줄 수 있는 것은 사실이다. 하지만 host별 config, permission,
Secret, transport와 사용자 승인 차이는 남고, MCP가 문서 파일·Git sync·webhook보다 단순하지 않은 경우도 많다.
integration contract를 MCP보다 상위에 두면 MCP의 장점을 쓰면서 protocol 종속을 피할 수 있다.

### 반론 4: local-first는 여러 장비 sync와 모바일 접근을 어렵게 한다

맞다. local-first는 local-only와 같지 않다. Git, 사용자가 고른 sync provider, 암호화 backup 또는 서비스 API를
선택적으로 쓸 수 있어야 한다. 중요한 조건은 cloud copy가 canonical owner를 불명확하게 만들지 않고 export와
provider 교체가 가능해야 한다는 것이다.

### 반론 5: 기존 제품을 조합하면 직접 만든 통합보다 UX가 파편화된다

초기에는 그렇다. Setup은 stable link, status, resume entrypoint와 공통 error/recovery 표현으로 파편화를 줄일 수
있다. UX 통일을 위해 원본 데이터와 실행 권한까지 흡수하면 단기 편의보다 장기 drift와 장애 반경이 커질 수 있다.

## 14. 불확실성

- 사용자의 실제 하루/주간 업무에서 가장 빈번한 세 흐름과 각 도구의 사용 비중이 아직 측정되지 않았다.
- Dashboard와 background server가 기본 경로인지 가끔 쓰는 ops 도구인지 근거가 부족하다.
- 첫 문서·계획 client, 첫 외부 업무 서비스, 첫 MCP server/client 조합이 정해지지 않았다.
- 여러 장비 간 문서·state sync와 암호화 backup에 사용할 provider 및 충돌 정책이 없다.
- Workbench optional profile이 실제 bootstrap과 doctor 계약에 미칠 영향은 구현 검증이 필요하다.
- adapter maturity tier의 운영 비용이 1인 프로젝트에 과하지 않은지 작은 pilot로 확인해야 한다.
- chezmoi, Home Manager, Obsidian, n8n, Home Assistant의 원칙은 유용한 비교 근거지만 대상 사용자와 문제 domain이
  다르므로 그대로 적용할 수 없다.
- 2026-08-10의 공식 문서는 향후 변경될 수 있다. 특히 MCP specification version과 client별 지원 범위는 구현 시점에
  다시 확인해야 한다.

## 15. 출처

모든 웹 자료는 **2026-08-10 확인**했으며 공식 문서·프로젝트 1차 자료를 우선했다.

### 내부 근거

- [`README.md`](../../README.md) — 현재 제품 설명, 설치·운영 진입점
- [`PRODUCT-PLAN.md`](../PRODUCT-PLAN.md) — 기존 제품 정의, 사용자 여정, 미결정과 위험
- [`raw/current-system.md`](current-system.md) — 현재 기능, owner와 안전 경계
- [`raw/repository-baseline.md`](repository-baseline.md) — platform profile, lock drift, 문서 충돌
- [`raw/validation-baseline.md`](validation-baseline.md) — 검증 범위와 미검증 장비/흐름
- [`workbench/README.md`](../../workbench/README.md) 및 `workbench/docs/` — state, backend, Dashboard, Secret,
  Task, worktree의 구현 계약

### 외부 1차 자료

- [chezmoi — What does chezmoi do?](https://www.chezmoi.io/what-does-chezmoi-do/) — 다중 장비,
  단일 source, 보안, dry-run, 원자성, 이탈 가능성 (2026-08-10 확인)
- [chezmoi — Setup](https://www.chezmoi.io/user-guide/setup/) — 공통 source와 machine-local config,
  diff/apply 흐름 (2026-08-10 확인)
- [Home Manager Manual — NixOS module](https://nix-community.github.io/home-manager/installation/nixos.html) —
  선언적 사용자 환경과 `home.stateVersion` (2026-08-10 확인)
- [Home Manager Manual — NixOS options](https://nix-community.github.io/home-manager/options/nixos/home-manager.html) —
  기존 파일의 backup·충돌 처리 선택지 (2026-08-10 확인)
- [Development Containers](https://containers.dev/) — 공개 Development Container Specification과
  supporting tools (2026-08-10 확인)
- [Obsidian Manifesto](https://obsidian.md/about) — device-local data, 공개 파일 형식, 확장성과 독립성
  (2026-08-10 확인)
- [Obsidian URI](https://obsidian.md/help/uri) — open/new/search 중심의 제한된 cross-app action
  (2026-08-10 확인)
- [n8n Documentation](https://docs.n8n.io/) — self-host 가능한 workflow automation과 integration 범위
  (2026-08-10 확인)
- [n8n Security audit](https://docs.n8n.io/hosting/securing/security-audit/) — filesystem/code/community node/
  webhook 위험 모델 (2026-08-10 확인)
- [n8n Source control environments](https://docs.n8n.io/source-control-environments/create-environments/) —
  Git 기반 환경, 양방향 흐름의 덮어쓰기·데이터 손실 위험 (2026-08-10 확인)
- [Home Assistant](https://www.home-assistant.io/) 및
  [Home Assistant Green](https://www.home-assistant.io/green) — local control, privacy, offline 접근
  (2026-08-10 확인)
- [Home Assistant Integration Quality Scale](https://developers.home-assistant.io/docs/core/integration-quality-scale/) —
  integration의 증거 기반 품질 tier, owner, 오류 복구와 diagnostics (2026-08-10 확인)
- [MCP Architecture overview](https://modelcontextprotocol.io/docs/learn/architecture) — host/client/server 책임,
  protocol scope, transport와 capability negotiation (2026-08-10 확인)
- [MCP Architecture specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/architecture) —
  host의 permission/consent, server 격리와 composability (2026-08-10 확인)
- [MCP Authorization specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) —
  최소 권한 scope와 resource-bound token (2026-08-10 확인)
- [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices) —
  authorization, session, token 관련 공격과 완화 (2026-08-10 확인)
