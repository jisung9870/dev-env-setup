# 에이전트 관리와 멀티 에이전트 오케스트레이션 전략

> 상태: 제품 결정용 조사 초안
> 기준일·외부 자료 확인일: **2026-08-10**
> 범위: 개인의 local-first 운영 환경. 팀용 control plane, 상시 cloud scheduler, MCP 기반 실행은 제외한다.

## 1. 조사 방식과 판단 표기

이 문서는 `README.md`, `plan/PRODUCT-PLAN.md`, `plan/README.md`, `plan/raw/*.md`와
Workbench의 `docs/agents.md`, `docs/tasks.md`, `docs/worktrees.md`를 현재 구현의 1차 근거로 삼았다.
Orca는 공개 공식 문서와 이 장비의 version-matched CLI guide를 함께 확인했다. 로컬 Orca runtime은
`orca-ide status --json`에서 **1.4.177 / ready**로 확인됐다.

- **사실**: 코드·로컬 문서·공식 제품 문서·실행 결과로 확인한 내용이다.
- **추론**: 사실에서 도출했지만 실제 사용 실험이 더 필요한 판단이다.
- **제안**: 채택 여부를 결정해야 하는 제품 선택이다.
- **불확실**: API 안정성, 실제 사용량처럼 현재 근거만으로 확정할 수 없는 내용이다.

## 2. 실제 사용자 문제

개인 운영 환경의 문제는 “에이전트를 여러 개 실행하는 방법”보다 **어떤 작업을 누가, 어디서,
어떤 권한으로 실행 중이며 결과를 어떻게 안전하게 회수할지**를 잊지 않는 데 있다.

| 대상 | 실제 사용자 문제 | 실패했을 때의 비용 | 필요한 최소 계약 |
|---|---|---|---|
| agent session | 같은 Codex/Claude라도 어느 repo·계정·모델·권한으로 시작했는지 흩어진다 | 잘못된 맥락 재개, 중복 실행, 권한 과다 | provider, cwd/worktree, 시작 시각, 상태, 재개 위치 |
| task | terminal title이나 process 이름은 목표·완료 조건·결과를 설명하지 못한다 | “끝남”과 “성공함”을 혼동 | 사용자 목표, owner, 상태, 결과 요약, 산출물 참조 |
| worktree | Git 실체, Orca 상태, Workbench registry가 어긋날 수 있다 | 다른 branch 수정, dirty 작업 삭제 | Git porcelain 우선, canonical path/branch/HEAD, managed 여부 |
| terminal | handle과 pane은 재시작·backend마다 안정성이 다르다 | stale jump/stop, 잘못된 terminal 입력 | runtime-scoped reference, 재탐색, 마지막 관찰 시각 |
| run/dispatch | 하나의 목표와 여러 task, 각 task의 시도(attempt)가 구분되지 않으면 늦은 완료가 현재 시도를 덮는다 | retry 중복, 잘못된 완료 판정 | run → task → dispatch, attempt identity, terminal outcome |
| 상태 | working/idle/waiting은 완료 결과가 아니며 observed 상태는 추론일 수 있다 | 조기 종료 또는 영구 대기 | provenance, confidence, terminal/active 상태 분리 |
| 승인 | 에이전트·backend별 approval와 sandbox 기본값이 다르다 | credential 노출, 외부 변경, 파괴적 실행 | effective policy 표시, 위험 action 별도 승인, fail-closed |
| audit | prompt 전문은 민감하지만 아무 기록도 없으면 장애를 재구성할 수 없다 | 원인·책임·복구 경로 상실 | metadata event, actor/target/action/outcome, 민감값 제외 |
| 결과 회수 | terminal 출력, Git diff, `worker_done`, PR 등이 서로 다른 결과 표면이다 | 완료 후 무엇을 검토할지 다시 탐색 | 요약, outcome, 변경 파일, commit/PR, 검증, 남은 일 |

### 현재 확인된 기반

- **사실:** Workbench는 자신이 시작한 Codex/Claude task를 schema-v1 registry에 저장하고,
  `managed`와 tmux에서 관찰한 `observed` task를 권한까지 구분한다. observed task에는 stop 권한을
  주지 않는다.
- **사실:** Workbench의 worktree 삭제는 registry만 믿지 않고 Git porcelain, 경로, branch, dirty,
  lock 상태를 직전에 재검증한다.
- **사실:** Orca는 실제 Git worktree마다 agent terminal과 UI surface를 묶고, CLI agent를 교체 가능하게
  실행한다. 공식 문서는 terminal handle이 runtime-scoped라 재시작 후 다시 찾아야 한다고 설명한다.
- **사실:** 현재 설치된 Orca orchestration은 Run, Task, Dispatch, persistent message, question,
  decision gate, `worker_done`, worker release를 구분한다. 이 세션도 task와 dispatch ID를 함께 써서
  늦은 완료를 fence한다.
- **추론:** 두 제품 모두 agent/task/worktree lifecycle을 소유하려 하면 “어느 registry가 완료와 stop의
  최종 권한자인가”가 새 사용자 문제가 된다. 기능 수보다 **단일 mutation owner**가 중요하다.

## 3. 제품 경계

권고하는 경계는 다음과 같다.

```text
Workbench: 개인 업무·프로젝트의 장기 index, 정책, cross-backend resume
    └─ Orca adapter: capability/health 확인, 선택적 open·launch·jump 위임
         └─ Orca: Orca worktree·terminal·agent session·Run/Task/Dispatch의 runtime owner
              └─ Codex/Claude/기타 CLI: 실제 모델 session과 tool execution owner

Git: worktree/branch/dirty의 최종 사실
tmux + nvim + bb: Orca와 Workbench가 없어도 쓰는 독립 경로
```

- **제안:** Workbench의 장기 Task와 Orca의 orchestration Task를 같은 객체로 합치지 않는다. 초기에는
  `provider=orca`와 외부 reference만 연결한다.
- **제안:** Orca가 만든 terminal·worktree·dispatch는 Orca가 변경 권한을 가진다. Workbench는 Orca가
  명시적으로 검증한 typed operation만 호출한다.
- **제안:** Git 사실은 어느 registry보다 우선한다. Workbench가 worktree를 제거할 때 지키는 현재
  fail-closed 계약을 Orca adapter에서도 낮추지 않는다.
- **제안:** MCP는 필요하지 않다. version-matched Orca CLI/RPC adapter로 충분하며, MCP가 향후 제공돼도
  transport 선택일 뿐 identity·ownership·approval의 근거가 되어서는 안 된다.

## 4. 세 선택지 비교

평점은 이 개인 환경에서 1(불리)~5(유리)이며, 합계보다 근거와 중단 가능성을 우선한다.

| 기준 | (1) Orca를 선택 backend/client로 관리 | (2) Workbench 공통 control/registry가 Orca에 실행 위임 | (3) 제한된 자체 orchestration |
|---|---:|---:|---:|
| 첫 사용자 가치까지 시간 | **5** | 3 | 2 |
| Orca 기능 중복 회피 | **5** | 2 | 1 |
| provider portability | 3 | **5** | 4 |
| Orca 장애 시 독립 경로 | **5** | 3 | **5** |
| 일관된 cross-backend audit | 2 | **5** | 4 |
| lifecycle 정합성 난도 | **4** | 2 | 2 |
| 장기 유지보수 비용 | **5** | 2 | 1 |
| 현재 근거에 맞는 범위 | **5** | 3 | 1 |

### 선택지 1 — cmux처럼 선택 backend/client

Workbench는 Orca availability/capability를 확인하고, 사용자가 고른 경우 Orca surface로 open·jump하며,
나중 단계에서 제한된 launch를 위임한다. Orca 내부 Run/Task/Dispatch를 복제하지 않고 외부 reference와
결과 요약만 보관한다.

- **장점:** Orca의 worktree-native UI, terminal, 원격 runtime, provider 지원, orchestration을 재구현하지
  않는다. Orca가 없어도 현재 tmux/LazyVim/binbox 경로가 남는다.
- **비용:** Workbench 전체 overview에서 Orca 내부 DAG를 완전하게 편집하기 어렵고, 장기 audit가 Orca
  보존 정책에 일부 의존한다.
- **판단:** 현재 채택할 선택지다. 선택 backend라는 지위는 cmux와 유사하지만, Orca에는 task/dispatch
  상태가 있으므로 cmux adapter보다 더 엄격하게 dual ownership을 피해야 한다.

### 선택지 2 — Workbench 공통 control/registry + Orca 실행 위임

Workbench가 provider-neutral Run/Task/Dispatch를 정의하고 Orca는 executor가 된다. 사용자는 하나의
queue와 audit를 얻지만 Workbench↔Orca 양쪽 상태 전이와 retry를 조정해야 한다.

- **장점:** tmux·Orca·향후 provider를 같은 장기 모델에서 조회하고 정책·승인을 중앙화할 수 있다.
- **비용:** Orca에 이미 있는 Run/Task/Dispatch, 질문, gate, completion을 다시 표현해야 한다. timeout,
  재시작, 늦은 completion, remote disconnect마다 reconciliation 로직이 필요하다.
- **판단:** 지금은 보류한다. 선택지 1의 실제 사용에서 “Orca와 tmux를 넘나드는 동일 목표의 장기
  추적”이 반복적으로 가장 큰 불편임이 증명될 때만 승격한다.

### 선택지 3 — 제한된 자체 orchestration

Workbench가 local queue, dependency, worker launch, message, approval, completion을 구현하고 각 agent
CLI를 직접 실행한다.

- **장점:** Orca 없이 동작하며 좁은 개인 workflow에 최적화할 수 있다.
- **비용:** 이미 구현된 Workbench managed task를 넘어 attempt fencing, crash recovery, terminal
  cleanup, provider resume, question/gate, remote worker까지 소유하게 된다. 안전·테스트·migration 비용이
  사용자 한 명의 가치보다 커질 가능성이 높다.
- **판단:** 범용 구현은 채택하지 않는다. fallback은 현재처럼 “단일 agent 시작·관찰·안전한 jump”까지만
  유지하고, DAG scheduler나 message bus를 만들지 않는다.

## 5. 주요 위험과 통제

| 위험 | 사실·근거 | 판단과 통제 제안 |
|---|---|---|
| Orca 종속 | Orca CLI와 runtime capability는 빠르게 확장되고 terminal handle은 runtime-scoped다 | adapter version/capability probe, contract fixture, `unavailable` 명시. Orca 없을 때 tmux/direct agent 경로 유지 |
| 기능 중복 | Workbench와 Orca 모두 agent/worktree/task를 표현한다 | object 병합 금지, mutation owner 1개, 외부 reference projection만 저장 |
| 유지보수 | 선택지 2·3은 상태 전이와 recovery를 자체 소유한다 | 1개 adapter와 최소 typed command만 유지, transcript parser 금지 |
| provider portability | Orca는 여러 CLI/custom agent를 지원하지만 provider별 resume·status·approval이 다르다 | 공통 필드는 최소화하고 provider-specific capability를 보존. unsupported를 가짜 공통 기능으로 채우지 않음 |
| 장애 시 독립성 | Setup 원칙상 Workbench/Dashboard 없이 terminal 기본 흐름이 남아야 한다 | `codex`/`claude`/tmux 직접 실행, plain Git, nvim을 recovery runbook에 유지 |
| credential 노출 | Orca는 기존 agent 계정을 사용하고 원격 host도 지원한다 | credential 복사·중앙 저장 금지, host별 기존 credential reference만 사용, audit에서 env/prompt/stdout 기본 제외 |
| 권한 과다 | Orca 공식 기본 launch arguments는 여러 agent의 permission bypass flag를 미리 넣는다 | **Workbench가 시작하는 session에는 그 기본을 묵시적으로 승계하지 않음**. effective sandbox/approval을 시작 전 표시하고 policy profile을 명시 |
| 파괴적 작업 | worktree 삭제, terminal stop, shell/network action은 복구 난도가 다르다 | delete/stop은 typed action+대상 재검증+명시적 확인. 외부/observed 대상은 read-only. `force` 기본 금지 |
| audit 민감성 | prompt와 terminal transcript에는 code·secret·업무 내용이 섞일 수 있다 | 기본 audit는 ID, 시각, actor, provider, action, outcome, file/commit reference만. 전문 수집은 opt-in·보존기한 필요 |

### 권한에 대한 별도 결론

- **사실:** Orca 공식 문서는 “worktree 자체를 sandbox로 본다”는 이유로 Codex의
  `--dangerously-bypass-approvals-and-sandbox`, Claude의 `--dangerously-skip-permissions` 등을 기본
  launch argument로 둔다.
- **사실:** OpenAI 공식 문서는 local Codex의 기본 방어를 OS-enforced sandbox와 approval policy의
  두 계층으로 설명하며, 기본적으로 workspace write와 network 제한을 둔다. Anthropic도
  `--dangerously-skip-permissions`에 “use with caution”을 명시한다.
- **추론:** Git worktree는 branch 간 파일 충돌은 줄이지만 home directory, cloud credential, network,
  외부 filesystem에 대한 보안 경계는 아니다.
- **제안:** Setup/Workbench의 안전 기준은 Orca 기본값보다 보수적으로 둔다. `safe`(sandbox+on-request),
  `trusted-local`(명시적 확대), `infrastructure`(read/plan 위주, apply 별도 확인) 같은 profile을 먼저
  정의하고, full bypass는 매 session 명시 선택과 audit event가 있을 때만 허용한다.

## 6. build-vs-integrate 결정 기준

새 공통 기능은 아래 질문을 순서대로 통과해야 한다.

1. 이 문제가 최근 실제 사용에서 반복됐는가? 문서상 가능성이 아니라 최소 3회 이상의 사례가 있는가?
2. Orca 또는 agent provider가 이미 stable typed capability를 제공하는가? 그렇다면 integrate한다.
3. 기능이 두 개 이상의 backend에 같은 의미로 존재하는가? 하나뿐이면 provider capability로 남긴다.
4. source of truth와 mutation owner를 한 문장으로 말할 수 있는가? 못 하면 구현하지 않는다.
5. 실패해도 direct terminal/Git 경로로 복구 가능한가?
6. 파괴적 작업이면 stable identity, 직전 재검증, explicit approval, idempotency/fencing이 모두 있는가?
7. adapter 유지·migration 비용이 절약되는 주간 사용자 시간보다 작은가?

다음 조건이면 **integrate**한다: stable CLI/ID, read/jump 중심, owner가 Orca로 명확함. 다음 조건이면
Workbench에 **build**할 수 있다: backend-neutral한 장기 개인 업무 metadata, 안전 정책, 결과 index처럼
Orca 바깥에서도 가치가 있고 runtime lifecycle을 복제하지 않는 기능. scheduler, transcript state
inference, provider별 permission bypass 흡수는 만들지 않는다.

## 7. 최소 통합 범위

첫 adapter의 범위를 아래 여섯 가지로 제한한다.

1. `status --json`과 capability/version 확인. 미지원은 degraded가 아니라 명시적 unavailable로 표시.
2. Orca worktree·agent terminal의 **읽기 전용** 요약과 마지막 관찰 시각. terminal handle은 영구 저장하지
   않고 매 runtime에서 다시 찾는다.
3. canonical repo/path/branch와 Orca external ID를 이용한 open/jump. Git porcelain과 충돌하면 거부.
4. 사용자 명시 action으로 Orca에서 새 session을 시작하되 agent, worktree, effective permission profile,
   setup policy를 미리 보여준다.
5. outcome summary, 변경 파일, 검증, commit/PR 같은 결과 pointer를 Workbench Task에 연결. prompt·terminal
   전문은 기본 수집하지 않는다.
6. stop/remove는 첫 단계에서 제공하지 않는다. 이후에도 Workbench가 시작했고 Orca가 현재 ownership을
   재검증한 대상에만 별도 confirmation으로 허용한다.

초기 schema는 공통 lifecycle 복제가 아니라 다음 reference면 충분하다.

```text
provider=orca
external_runtime_id (ephemeral)
external_worktree_id + canonical_repo/path/branch
external_run/task/dispatch_id (있을 때만 opaque reference)
last_observed_state + observed_at + confidence
launch_policy_profile
result_summary + files/commit/pr/test references
```

## 8. 단계별 실험과 승격·중단 기준

### E0 — 관찰 기준선

- 2주 또는 agent session 20개 동안 direct tmux, Workbench managed task, Orca 사용을 기록한다.
- command/prompt 전문 없이 시작·복귀·결과 회수 시간, stale reference, fallback 횟수, 권한 prompt/bypass
  선택만 로컬 metadata로 센다.
- **승격:** Orca가 실제 session의 30% 이상이거나, Orca session을 Workbench에서 찾고 싶은 사례가 3회 이상.
- **중단:** Orca가 실사용되지 않거나 현재 Workbench/tmux가 같은 문제를 충분히 해결함.

### E1 — read-only Orca adapter

- health/capability, summary, open/jump만 구현하고 20회 복귀를 검증한다.
- **성공:** 잘못된 worktree jump 0, stale handle 자동 재탐색 성공 95% 이상, Orca 부재 시 기존 경로 100% 유지.
- **중단:** 30일 안에 계약 파괴 변경이 2회 이상, 상태 의미를 transcript scraping 없이는 얻을 수 없음,
  Git/Orca identity가 1% 이상 모호함.

### E2 — 정책이 보이는 controlled launch

- 10개 비파괴 coding task를 Orca에 위임하고 safe profile을 기본으로 한다.
- **성공:** 모든 launch에 effective policy가 표시되고, 결과 pointer 회수 90% 이상, 중복 task 0.
- **중단:** Orca의 bypass 기본을 adapter에서 신뢰성 있게 override/검증할 수 없음, credential이 audit에
  노출됨, start retry의 idempotency를 증명하지 못함.

### E3 — orchestration pass-through

- E2 후에도 명확한 수요가 있을 때만 Orca-native Run/Task/Dispatch를 opaque reference로 노출하고,
  dependency 2~3단계인 실제 목표 10개를 관찰한다.
- **성공:** late completion 오귀속 0, 질문·승인 누락 0, 결과 회수 90% 이상, 수동 reconciliation 5% 미만.
- **중단:** Workbench가 Orca 상태를 양방향 복제해야만 동작함, orphan worker 1건 이상, 사용자가 두 task
  모델의 차이를 반복해서 이해하지 못함.

### 선택지 2 재검토 gate

다음이 모두 충족될 때만 공통 control/registry를 설계한다.

- Orca와 non-Orca backend를 가로지르는 동일 목표가 월 10회 이상이다.
- read-only projection으로 해결되지 않는 audit/queue 불편이 월 3회 이상이다.
- 최소 두 provider가 stable attempt ID와 terminal outcome을 제공한다.
- crash/restart/retry/late completion fixture를 먼저 작성할 수 있다.
- 30일 shadow mode에서 상태 불일치 1% 미만, destructive action 0건으로 통과한다.

## 핵심 결론

에이전트 관리의 핵심 제품 가치는 더 많은 agent를 자동 실행하는 것이 아니라 **실행 위치, 소유권,
권한, 상태의 신뢰도, 결과와 복구 경로를 한눈에 이해하는 것**이다. 현재 Orca는 worktree·terminal·여러
agent·Run/Task/Dispatch까지 Workbench가 새로 만들기에는 충분히 큰 실행 surface를 이미 제공한다.
Workbench는 개인 업무의 장기 index와 안전 정책을 맡고 Orca runtime lifecycle은 Orca가 맡아야 한다.

## 채택 권고

**선택지 1을 채택한다.** Orca를 cmux처럼 optional backend/client로 통합하되, Orca의 richer lifecycle을
감안해 초기 범위는 health, read-only summary, open/jump, 정책이 보이는 launch, 결과 pointer 회수로
제한한다. 선택지 2는 실제 cross-backend 수요가 gate를 통과할 때만 재검토하고, 선택지 3의 scheduler,
message bus, DAG는 만들지 않는다. MCP는 이 결정의 전제도 의존성도 아니다.

## 반론

1. **“Workbench가 공통 registry를 가져야 진짜 통합 도구다.”** 장기 업무 index에는 동의하지만 runtime
   Task/Dispatch까지 복제하면 통합이 아니라 reconciliation 제품이 된다. 먼저 external reference로
   실제 불편이 남는지 검증해야 한다.
2. **“Orca에 맡기면 종속된다.”** 맞다. 그래서 Orca 전용 상태를 Workbench 핵심 schema로 승격하지 않고,
   direct tmux/Git/agent 경로와 opaque reference를 유지한다. 좁은 adapter는 자체 orchestrator보다
   제거하기 쉽다.
3. **“개인용이면 permission bypass가 생산적이다.”** 신뢰된 coding task에서는 그럴 수 있다. 그러나 이
   환경은 AWS/Kubernetes/Terraform credential도 다룬다. worktree isolation만으로 외부 side effect를
   제한하지 못하므로 profile과 명시적 선택이 필요하다.
4. **“자체 구현이 개인 workflow에 더 잘 맞는다.”** 단일 agent launch와 observed task는 이미 그 장점을
   제공한다. multi-agent retry, question, cleanup, remote lifecycle까지 직접 소유할 근거는 아직 없다.

## 불확실성

- 실제 일상에서 Orca, Workbench managed task, direct tmux가 각각 얼마나 쓰이는지 데이터가 없다.
- 공개 Orca 문서와 설치된 1.4.177의 version-matched orchestration guide는 빠르게 변할 수 있으며,
  CLI contract의 장기 호환 기간은 확인되지 않았다.
- 실제 macOS+Orca/cmux, Windows+WSL, remote Orca Server에서 credential·terminal 재연결·결과 회수 smoke를
  아직 수행하지 않았다.
- agent provider마다 정확한 session ID, resume, exit outcome, permission reporting 수준이 다르다.
- metadata-only audit만으로 장애 원인을 충분히 재구성할 수 있는지, 또는 opt-in transcript가 필요한지
  실제 사례가 없다.
- 선택지 1이 Workbench와 Orca 두 개의 UI를 오가는 비용보다 더 큰 복귀 이점을 주는지는 E0/E1에서
  측정해야 한다.

## 출처

모든 웹 자료는 **2026-08-10**에 확인했다.

### 로컬 1차 자료

- `README.md`, `plan/PRODUCT-PLAN.md`, `plan/README.md`, `plan/raw/*.md`
- `workbench/docs/agents.md`, `workbench/docs/tasks.md`, `workbench/docs/worktrees.md`
- 설치된 Orca 1.4.177의 `orca-ide status --json`, `orca-ide skills get orchestration`

### Orca 공식·제품 자료

- [What is Orca?](https://www.onorca.dev/docs) — worktree별 agent terminal, 여러 CLI agent, local/remote 제품 경계
- [Worktrees](https://www.onorca.dev/docs/model/worktrees) — 실제 Git worktree, lifecycle, 외부 worktree 처리
- [Agents & sessions](https://www.onorca.dev/docs/model/agents-sessions) — session/state와 기본 permission-bypass launch argument
- [Orca CLI reference](https://www.onorca.dev/docs/cli/reference) — runtime-scoped terminal handle, typed worktree/terminal 명령
- [Skills registry & MCP](https://www.onorca.dev/docs/cli/skills) — message/task/dispatch/gate orchestration skill과 MCP의 별도 위치
- [Ways to run Orca](https://www.onorca.dev/docs/ways-to-run) — local, SSH, remote server, per-workspace environment
- [stablyai/orca GitHub](https://github.com/stablyai/orca) — 공개 제품 repository와 지원 agent 범위

### 관련 1차 자료

- [cmux CLI reference](https://cmux.com/docs/api) — workspace/surface typed CLI·socket와 access mode
- [OpenAI: Agent approvals & security](https://learn.chatgpt.com/codex/agent-approvals-security) — OS sandbox, approval policy, network control의 분리
- [Anthropic: Claude Code CLI reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage) — resume/session과 `--dangerously-skip-permissions` 경고
