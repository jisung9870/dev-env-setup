# 기술·연동·보안 타당성 검토

> 조사일: 2026-08-10
> 범위: local-first 구조, 데이터·검색·자동화, adapter/plugin, 사용자 인터페이스, 외부 연동,
> 개인정보·credential·권한·감사·복구·공급망·파괴적 동작
> 성격: 현재 구현을 바꾸는 설계 승인이 아니라 제품 기획을 위한 기술 검토

## 1. 판정 방법

이 문서는 다음 표기를 사용한다.

- **[사실]** 저장소 코드·현행 문서 또는 아래 1차 자료에서 확인한 내용이다.
- **[추론]** 확인한 사실로부터 도출한 해석이며 구현 검증을 거치지 않았다.
- **[제안]** 채택 여부를 결정해야 하는 설계·운영 권고다.
- **[불확실]** 실제 사용량, 대상 서비스, 장비 smoke 등 증거가 없어 지금 확정할 수 없는 내용이다.

읽은 저장소 자료는 root `README.md`, `plan/PRODUCT-PLAN.md`, `plan/README.md`, `plan/raw/*.md`,
`workbench/README.md`, 그리고 Workbench의 backend, Dashboard, Secret, Task, workflow, worktree 구현
문서다. 외부 사실은 공식 규격과 서비스 제공자의 1차 문서를 우선했고, 모든 URL의 확인일은
2026-08-10이다.

## 2. 요약 판정

**[추론] 기술적으로 타당하다.** 다만 성공 가능성이 높은 형태는 “모든 데이터를 가져와 모든 일을
대신하는 개인용 SaaS 복제품”이 아니라, 로컬에 정규화한 핵심 상태와 정책을 두고 기존 도구와 외부
서비스를 좁은 adapter로 연결하는 개인 운영 환경이다.

현재 Workbench는 이 방향에 필요한 기반을 상당 부분 갖췄다. schema version, atomic replacement,
backup, managed/observed 구분, typed action, argument-array 실행, loopback Dashboard, metadata-only
기록이 이미 있다. 반면 전체 registry를 여러 TOML/JSON 파일로 나눈 구조는 connector 수, 관계형 조회,
동시 쓰기, 검색 색인이 커지면 복잡해진다. 그렇다고 지금 바로 SQLite나 event sourcing으로 전면
재작성할 근거도 없다.

가장 현실적인 순서는 다음과 같다.

1. 현행 CLI와 파일 계약의 복구성을 먼저 완성한다.
2. 공통 `item/link/source_ref/action_run` 모델을 작은 범위에서 검증한다.
3. 읽기 전용 파일·Git adapter와 캘린더 한 개를 먼저 붙인다.
4. 그 다음에만 직접 API와 polling/delta sync를 도입한다.
5. webhook, MCP 관리, 모바일 승인은 실제 필요가 확인될 때 선택적으로 추가한다.
6. 범용 plugin SDK, 항상 켜진 cloud relay, 범용 MCP proxy, 독립 desktop shell은 뒤로 미룬다.

## 3. 현재 구조의 타당성

### 3.1 확인된 강점

- **[사실]** Workbench는 project, environment, Secret, session, worktree, Agent/Task, workflow를
  schema-v1 TOML/JSON으로 로컬에 저장하고, 이전 파일이 있으면 backup 후 임시 파일·flush·rename·검증을
  수행한다. Windows에서 rename 교체가 Unix와 같은 원자성을 보장하지 않는다는 제한도 문서화돼 있다.
- **[사실]** Git worktree 실체는 Git porcelain, tmux session 실체는 tmux, observed Task는 live tmux
  snapshot을 권위 있는 관찰 원천으로 사용한다. Workbench registry만 보고 외부 자원을 삭제하지 않는다.
- **[사실]** Dashboard는 `127.0.0.1`에만 bind하고 per-process token, same-origin 검사, 16 KiB body
  제한, unknown-field 거부, CSP와 no-store를 사용한다. 임의 command/path/argument 입력은 받지 않는다.
- **[사실]** Secret 값은 argv에 받지 않고, 목록·JSON·activity에는 metadata만 남긴다. age identity와
  암호문을 함께 가진 사용자는 전체 값을 복호화할 수 있고, identity 유실 시 복구할 수 없다.
- **[사실]** backend는 작은 capability interface이고, 명시적으로 고른 backend의 실패를 자동 fallback으로
  숨기지 않는다. subprocess는 shell string 대신 executable과 argument array로 실행한다.
- **[사실]** workflow는 compiled allowlist이며 `apply`, `destroy`, force-delete, 임의 shell을 포함하지
  않는다. Secret redaction이 변형·인코딩·파일·network 유출을 막는 sandbox가 아니라는 한계도 명시한다.

이들은 local-first와 사용자 통제권의 좋은 출발점이다. 특히 “관찰 가능”과 “변경 권한 보유”를 분리한
managed/observed 모델은 외부 서비스 connector에도 그대로 확장할 가치가 있다.

### 3.2 확인된 구조적 갭

- **[사실]** 여러 registry가 각자 backup과 일부 file lock을 구현하지만, 서로 다른 파일을 함께 바꾸는
  cross-domain transaction은 없다.
- **[사실]** Activity는 200개, workflow 결과는 50개 등 bounded history다. 이는 개인정보 최소화에는
  유리하지만 보안 감사나 장기 복구 기록과 동일하지 않다.
- **[사실]** lock snapshot은 현재 4개 child 중 3개가 drift했고 report-only다. 따라서 지금 상태만으로는
  “설치된 실행물이 검증된 소스에서 왔다”는 공급망 보장을 하지 못한다.
- **[사실]** macOS/cmux, Windows/WSL, 별도 Linux 장비, 장기간 background server는 이번 기준선에서
  실제 장비로 증명되지 않았다.
- **[사실]** MCP, 메일, 캘린더, Slack/Teams의 실제 client·scope·credential inventory는 아직 없다.
- **[추론]** 이 상태에서 범용 connector framework부터 만들면 아직 모르는 인증·동기화 차이를 추상화
  안으로 숨기고, Workbench가 새로운 단일 장애 지점이 될 가능성이 크다.

## 4. 목표 시스템 개념 구조

```text
                         사용자 제어면
       CLI (primary) ─ Local Web UI (inspect/approve) ─ Mobile helper (later)
               │              │                         │
               └──────── typed command / query ─────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │ Workbench Core                    │
                    │ policy · ownership · action gate  │
                    │ scheduler · sync cursor · audit   │
                    └───────────┬───────────┬───────────┘
                                │           │
             ┌──────────────────▼──┐   ┌────▼─────────────────┐
             │ Local canonical data │   │ Credential broker/ref │
             │ state + search index │   │ OS vault/age, no value │
             │ append-only receipts │   │ in ordinary records    │
             └──────────┬───────────┘   └────┬─────────────────┘
                        │                    │ short-lived resolve
       ┌────────────────┴────────────────────┴───────────────────┐
       │ trusted in-process adapters / isolated subprocess connectors │
       └── filesystem ─ Git ─ CalDAV/API ─ mail ─ Slack/Graph ─ MCP ┘
                                │
                      외부 서비스는 계속 원본 owner
```

**[제안]** “core가 모든 원본을 소유한다”가 아니라 다음 네 층으로 책임을 나눈다.

1. **Canonical core:** 서비스 비종속 ID, 상태, 관계, 사용자 정책, action receipt를 소유한다.
2. **Projection/cache:** 외부 데이터를 필요한 최소 필드만 로컬에 투영한다. 지워도 다시 만들 수 있어야 한다.
3. **Source adapter:** 외부 ID, cursor, ETag, rate limit, API 오류를 보존하고 서비스별 차이를 숨기지 않는다.
4. **Secret boundary:** record에는 `credential_ref`만 넣고 실제 값은 실행 순간에 제한적으로 resolve한다.

외부 서비스의 원본 message/event를 로컬 canonical record로 바꿨다고 해서 Workbench가 그 외부 자원의
삭제 권한까지 얻지는 않는다. `provenance`, `ownership`, `authority`, `confidence`를 별도 필드로 유지한다.

## 5. local-first 데이터 전략

### 5.1 데이터 분류와 source of truth

| 분류 | 예 | 권위 원천 | 로컬 저장 원칙 |
|---|---|---|---|
| 사용자 선언 | project, profile, connector enable, 정책 | 로컬 Workbench | Git 가능한 비밀 없는 선언 + versioned migration |
| 로컬 운영 상태 | Task, action run, sync cursor, ownership | Workbench | crash-safe 저장, backup, audit receipt |
| 외부 projection | 메일 header, Slack message ref, calendar event | 외부 서비스 | 최소 필드 cache, source ID/ETag/cursor 보존 |
| 생성 산출물 | note, plan, report | 파일/Git | 사람이 읽을 수 있는 Markdown/JSON/ICS 우선 |
| 검색 색인 | token, FTS index, embedding | 재생성 가능 projection | 원문과 분리, 삭제·재구축 가능 |
| credential | OAuth refresh token, webhook URL, age key | OS vault/age/사용자 | reference만 일반 DB에 저장, log·Git 제외 |
| audit receipt | 누가/무엇을/왜/결과 | Workbench | append-only에 가깝게, 민감 payload 제외 |

### 5.2 파일을 유지할 것인가, SQLite로 옮길 것인가

**[제안] 당장은 이중 전략이 적절하다.** 사람이 직접 복구해야 하는 선언은 TOML/JSON/Markdown으로
유지하고, connector sync·관계·검색·queue처럼 쓰기 빈도와 질의 복잡도가 높은 데이터만 SQLite에 넣는다.

- 현행 `projects.toml`, profile, environment metadata는 portable configuration으로 유지한다.
- action run, connector cursor, external projection, relation, full-text index는 필요가 생길 때 하나의
  `workbench.db`에 둔다.
- DB가 생겨도 `wb export --portable` 같은 비밀 없는 NDJSON/JSON snapshot을 제공한다.
- DB 파일 자체를 Git sync하지 않는다. multi-device merge를 database file 공유로 해결하지 않는다.

**[근거]** SQLite의 Online Backup API는 실행 중인 DB를 일관된 snapshot으로 복사할 수 있다. WAL은
`-wal`, `-shm` 동반 파일과 checkpoint 운용이 생기므로 DB 파일을 단순 `cp`/Git 동기화하는 방식은
피해야 한다. 자세한 외부 근거는 출처 S1, S2다.

**[반론]** 전부 SQLite로 모으면 transaction과 query는 단순해진다. 그러나 비상시에 텍스트 편집기로
복구할 수 있는 장점, Git diff, 기존 schema-v1 계약을 잃는다. 현재 데이터 양과 동시성 측정 없이 전면
이전하는 것은 비용이 더 크다.

### 5.3 최소 canonical model

**[제안]** 서비스별 객체를 하나의 거대한 공통 schema로 평탄화하지 말고, 작은 공통 envelope와
서비스별 payload를 분리한다.

```text
Context    {id, boundary=personal|work, policy_ref, vault_ref, allowed_destinations}
Item       {id, context_id, kind, title, status, occurred_at, source_ref, sensitivity, revision}
SourceRef  {connector_id, external_type, external_id, etag, observed_at, cursor_epoch}
Link       {from_id, relation, to_id, provenance, confidence}
ActionRun  {id, action_type, target_ref, requested_by, policy_decision,
            idempotency_key, started_at, finished_at, outcome, recovery_hint}
Connector  {id, kind, enabled, capability_set, credential_ref, sync_policy, health}
```

- `Context`는 단순 tag가 아니라 account, credential vault, search/export 범위와 실행 환경을 묶는 최상위
  보안 경계다. personal↔work 원문 복제와 cross-context write는 명시적 정책 없이는 fail-closed한다.
- 원본 payload가 꼭 필요하면 connector namespace 아래 암호화하거나 짧은 TTL cache로 둔다.
- `kind`별 typed schema와 migration test를 둔다. unknown field를 조용히 버리지 않는다.
- 모든 시간은 UTC/RFC3339로 저장하고 UI에서 timezone을 적용한다.
- 삭제는 `tombstone + source confirmation`을 우선하며, 외부 삭제 성공과 로컬 projection 삭제를 분리한다.
- multi-device 충돌은 처음부터 CRDT로 풀지 않는다. 선언은 Git review, runtime state는 장비별 namespace,
  외부 projection은 source revision으로 다시 동기화한다.

## 6. 검색 전략

**[제안]** 첫 검색은 로컬 lexical search로 충분하다.

1. 파일은 `ripgrep` 또는 제한된 watcher가 path/title/tag/heading을 색인한다.
2. 구조화 데이터는 SQLite FTS5 또는 동등한 embedded index로 title, summary, tag만 색인한다.
3. 검색 결과는 반드시 `source`, `observed_at`, `sensitivity`, `open action`을 함께 보여준다.
4. Secret 값, token, private key, `.env`, mail body는 명시적 opt-in 전에는 색인하지 않는다.
5. 외부 서비스 검색은 로컬 검색 실패를 숨기는 fallback이 아니라 별도 source filter로 노출한다.
6. embedding/vector 검색은 사용 사례가 증명된 뒤, 로컬 모델과 원문 보존 정책을 먼저 결정한다.

**[추론]** 개인 데이터 규모에서는 semantic search보다 데이터 범위와 최신성 표시가 신뢰에 더 중요하다.
embedding은 민감 텍스트의 추가 사본, 모델 공급망, 재색인 비용을 만든다. 따라서 초기 필수 요소가 아니다.

## 7. 자동화 모델

### 7.1 실행 단위

**[제안]** 자동화는 임의 shell 문자열이 아니라 versioned `AutomationSpec`과 typed step으로 저장한다.

```text
trigger -> observe -> plan -> policy gate -> execute -> verify -> receipt
```

- trigger: manual, schedule, filesystem event, polling cursor, optional webhook
- plan: 어떤 자원을 읽고/쓰고/삭제하는지와 예상 diff
- gate: risk class, scope, foreground approval, credential availability
- execute: idempotency key, bounded timeout, cancellation, retry class
- verify: source를 다시 읽어 실제 결과 확인
- receipt: metadata, exit/status, provider request ID, 복구 지침; Secret/body 전문 제외

retry는 timeout/429/5xx 같은 transient failure에만 exponential backoff와 jitter를 적용한다. 4xx 권한
오류, schema 오류, destructive conflict는 자동 재시도하지 않는다. Slack은 rate limit 시 `429`와
`Retry-After`를 반환하므로 connector가 이를 존중해야 한다(S9).

### 7.2 webhook의 위치

**[추론]** local-first 장비는 항상 공개 HTTPS endpoint를 제공하지 않으므로 webhook을 기본 동기화
수단으로 삼기 어렵다. Microsoft Graph subscription은 만료·재인가·누락 lifecycle과 delta 보정이
필요하다(S8). webhook은 정확히 한 번 전달되는 event log가 아니라 “다시 조회하라”는 신호로 취급해야
한다.

**[제안]** 기본은 polling/delta cursor, webhook은 선택적 가속기다. webhook 수신이 필요하면:

- 작은 relay는 payload 전문 대신 서명 검증 가능한 event hint와 delivery ID만 보관한다.
- localhost로 arbitrary inbound tunnel을 열지 않는다.
- 중복·순서 역전·누락을 전제로 idempotency와 reconciliation을 구현한다.
- relay 장애 시 polling으로 수렴하며, relay가 connector credential을 보유하지 않게 한다.

## 8. adapter와 plugin 구조

### 8.1 권장 경계

**[사실]** 현행 backend의 `Name/Detect/OpenProject`와 Agent의 좁은 capability interface는 범용 RPC보다
작고 검증하기 쉽다.

**[제안]** 같은 원칙을 connector에 적용한다.

```text
Describe()                 version, capabilities, risk classes
Health(ctx)                auth/config/rate-limit 상태
Pull(ctx, cursor, limit)    변경 projection + next cursor
Plan(ctx, typedAction)      diff, permissions, reversibility
Apply(ctx, approvedPlan)    provider receipt
Reconcile(ctx, receipt)     실제 결과 재확인
```

- 신뢰된 core adapter는 Go in-process interface로 시작한다.
- 외부 기여 connector가 필요해질 때만 별도 process + versioned JSON protocol을 쓴다.
- plugin은 임의로 core DB를 열지 못하고, 최소 입력과 capability-scoped credential handle만 받는다.
- manifest에는 protocol version, executable digest, network domains, filesystem roots, requested scopes,
  supported actions, destructive class를 선언한다.
- plugin stdout은 protocol, stderr는 bounded diagnostic으로 분리하고 timeout/output limit을 둔다.

### 8.2 왜 범용 plugin SDK를 미루는가

**[추론]** Calendar, mail, Slack, Teams, MCP는 인증·증분 sync·삭제 의미·rate limit이 서로 다르다.
공통 CRUD를 먼저 정의하면 가장 중요한 차이를 문자열 option으로 밀어 넣게 된다. 첫 두세 connector에서
반복되는 계약을 확인한 뒤 SDK를 추출하는 편이 안전하다.

**[반론]** subprocess isolation은 crash 격리와 언어 독립성을 준다. 하지만 credential 전달, protocol
versioning, 배포·서명, 성능, debugging이 추가된다. 개인용 초기 단계에서는 trusted in-process adapter와
고정 dependency가 더 단순하다.

## 9. 인터페이스 역할과 도입 순서

| 인터페이스 | 가장 잘하는 일 | 한계·위험 | 권장 시점 |
|---|---|---|---|
| CLI | script, SSH, diff/dry-run, 복구, 정확한 오류 | overview와 다중 선택이 불편 | **현재 primary** |
| 로컬 Web UI | 현황, 검색, 관계 탐색, 승인, guide | browser token/XSS/CSRF, background server | **CLI 다음; 현행 강화** |
| Desktop shell | OS keychain, tray, notification, deep link | 배포·서명·업데이트·새 공격면, UI 중복 | 명확한 OS 통합 수요 후 |
| Mobile helper | 알림 확인, read-only inbox, 제한된 승인 | 원격 접근·분실 기기·push relay·phishing | 가장 나중, 좁은 기능 |

### 권장 도입 순서

1. **CLI:** 모든 상태 조회, dry-run, export/import, backup/restore, connector health의 기준 구현.
2. **Local Web UI:** 같은 core API의 projection만 사용하고, 검색·status·plan diff·foreground approval에 집중.
3. **모바일 보조:** 별도 “모바일 전체 앱”보다 read-only notification과 짧은-lived 승인 challenge부터 검토.
4. **Desktop:** keychain/notification/file watcher를 브라우저에서 안정적으로 제공할 수 없다는 증거가 있을
   때만 thin shell로 추가한다.

**[제안]** 모바일에서 destructive action을 직접 실행하지 않는다. 승인은 action ID, 대상, diff hash,
만료 시간, requesting device를 보여주고 서명하며, 실제 실행은 로컬 core가 최신 상태를 재검증한 뒤 한다.
Tailscale 같은 특정 네트워크 제품을 필수 전제로 삼지 말고 localhost, LAN/VPN, relay를 교체 가능한
transport로 둔다.

## 10. 연동 방식 비교

| 방식 | 장점 | 약점 | 적합한 용도 | 종속 최소화 |
|---|---|---|---|---|
| MCP | tool/resource 발견과 client 연결을 표준화 | server 자체의 권한·품질·공급망은 보장하지 않음 | AI client가 도구를 호출 | catalog/config/health만 관리, 호출 proxy는 기본 제외 |
| 직접 API | 기능·증분 sync·오류 의미를 가장 충실히 사용 | 서비스별 OAuth, rate limit, schema drift | Slack/Graph/Google 등 핵심 connector | service adapter와 canonical model 분리 |
| webhook | 낮은 지연, polling 절감 | 공개 endpoint, 재전송·누락·만료, relay 필요 | 변경 알림 가속 | hint로만 사용, reconciliation 유지 |
| 파일 시스템 | local-first, 투명, script/Git 친화 | watcher 차이, partial write, 민감 파일 | 문서·note·config·export | open format, atomic write, owned path |
| Git | history, review, merge, 복구 | DB/Secret/빈번한 runtime state에 부적합 | 선언·문서·자동화 spec | remote 교체 가능, signed release/hash |
| CalDAV/ICS | 개방형 캘린더 상호운용 | 제공자별 확장·OAuth 차이 | 일정 읽기/쓰기 | CalDAV 우선 가능, ICS export 보장 |
| IMAP/SMTP/JMAP | 표준 기반 메일 접근 | 폴더/label/thread 의미와 auth 차이 | read/triage/draft/send | 원문 EML/Maildir export, provider API는 adapter |
| Slack API | rich message/channel/event 기능 | Slack scope·rate limit·데이터 모델 종속 | 업무 알림·검색·요약 | 최소 scope, external ID 보존, export |
| Teams/Graph | mail/calendar/Teams를 한 auth plane에서 제공 | tenant 정책·subscription lifecycle·Graph 종속 | Microsoft 365 환경 | Graph adapter 격리, delta/poll fallback |

### 10.1 MCP

- **[사실]** 최신 확인한 MCP authorization 규격은 HTTP transport에서 OAuth 기반 authorization,
  resource audience validation, PKCE, HTTPS를 요구하며 token passthrough를 금지한다. STDIO transport는
  이 HTTP authorization flow 대신 환경에서 credential을 얻도록 권고한다(S3, S4).
- **[추론]** MCP는 transport와 tool contract이지 connector 신뢰 인증서가 아니다. 설치된 server가
  filesystem/network/credential에 접근하면 일반 plugin과 같은 공급망·권한 위험을 가진다.
- **[제안]** 1단계 MCP 범위는 catalog, pinned install source, client별 config generation, handshake health,
  requested capability/scope 표시, enable/disable과 rollback이다. 호출 payload 중앙 기록, 범용 proxy,
  downstream token 재사용은 제외한다.

### 10.2 직접 API와 OAuth

- native/CLI client는 confidential client secret을 안전하게 숨길 수 있다고 가정하지 않는다.
- system browser + authorization code + PKCE를 기본으로 하고, desktop loopback callback은 IP literal과
  임의 port를 사용한다. RFC 8252는 native app을 public client로 취급하고 loopback redirect를 정의한다(S5).
- OAuth security BCP는 authorization code flow, PKCE와 sender-constrained token 등 최신 완화책을
  설명한다(S6).
- refresh token은 OS keychain/credential manager가 가능하면 거기에, 그렇지 않으면 age store의 별도
  service/field에 저장한다. access token은 memory 또는 짧은-lived cache를 우선한다.
- scope는 connector 전체가 아니라 capability/read-write 단계별로 분리하고, scope 증가는 재승인을 요구한다.

### 10.3 Slack과 Teams

- **[사실]** Slack incoming webhook URL 자체가 Secret이고 특정 channel에 결합된다. webhook으로 보낸
  message는 그 방식으로 삭제할 수 없다(S7). 따라서 단순 알림 송신에는 작고 명확하지만 양방향 업무
  동기화 수단으로는 부족하다.
- **[사실]** Slack Web API는 OAuth bearer token과 method별 scope/rate limit을 사용한다(S9, S10).
- **[제안]** Slack 1차 기능은 사용자가 고른 채널로 알림 보내기 또는 제한된 읽기 중 하나만 선택한다.
  둘을 한 광범위 token으로 묶지 않는다.
- **[사실]** Graph change notification subscription에는 expiration과 reauthorization/missed/removed
  lifecycle이 있으며 누락 시 delta query 등 별도 복구가 필요하다(S8).
- **[제안]** Teams 자체와 Outlook mail/calendar를 “Microsoft connector 하나”로 과도하게 합치지 말고
  tenant/auth 공통층 위에 resource별 capability를 나눈다.

### 10.4 캘린더와 메일

- **[사실]** CalDAV는 WebDAV 위에 calendar access를 정의한 IETF 표준이다(S11). JMAP은 여러 데이터
  유형을 동기화하는 표준 protocol이다(S12).
- **[제안]** provider가 표준 protocol을 충분히 지원하면 CalDAV/JMAP/IMAP을 우선하되, Google/Microsoft의
  고유 기능이 핵심이면 공식 API adapter를 사용한다. “표준만 사용”을 목표로 기능과 신뢰성을 희생하지
  말고 항상 ICS, EML/Maildir, NDJSON 같은 탈출 경로를 제공한다.
- 메일 body와 attachment의 기본 local cache는 opt-in으로 한다. 처음에는 header, sender, date,
  message/thread ID, unread/flag 상태만 저장한다.
- 자동 발송은 draft 생성과 send를 분리하고, send는 foreground confirmation 또는 제한된 allowlist를 요구한다.

## 11. 서비스 종속 최소화 전략

**[제안]** “서비스를 쓰지 않음”이 아니라 “서비스를 교체할 비용을 측정 가능하게 유지”하는 것이 현실적이다.

1. canonical ID와 provider external ID를 분리한다.
2. provider payload를 core schema에 그대로 새기지 않고 connector namespace에 둔다.
3. config, automation spec, link, note는 공개 형식으로 export/import한다.
4. 모든 connector에 `disable`, `revoke guidance`, `export`, `purge projection`, `health`를 요구한다.
5. source가 삭제돼도 사용자가 만든 note/action receipt는 provenance와 함께 남길 수 있게 한다.
6. sync cursor 손상 시 full rescan할 수 있어야 하며 cursor를 유일한 복구 수단으로 삼지 않는다.
7. webhook relay, vector DB, cloud scheduler는 optional provider로 두고 core가 없어도 파일·CLI가 동작한다.
8. service-specific capability를 억지로 lowest common denominator로 만들지 않는다. portable core와
   explicit extension을 함께 둔다.

## 12. 개인정보·credential·권한

### 12.1 데이터 최소화

| 데이터 | 기본 정책 | 보존·삭제 |
|---|---|---|
| Secret/token/private key | 일반 DB·log·search 금지 | revoke/rotate 후 안전 삭제 시도, backup 사본 안내 |
| message/calendar body | 기본 미수집 또는 짧은 cache | connector별 TTL, purge 가능 |
| header/metadata | 기능에 필요한 필드만 | source별 retention 설정 |
| command output | terminal에만, receipt에는 요약 | 민감 패턴 redaction은 보조책 |
| audit | actor/action/target/result/recovery만 | bounded + security retention 분리 검토 |
| telemetry | local opt-in, category/result 정도 | remote 전송 기본 off |

**[제안]** 모든 field/type에 `public`, `personal`, `confidential`, `secret` sensitivity를 붙이고 UI, search,
export, log가 이를 전파하도록 한다. redaction은 저장 후 가리는 UI 기능이 아니라 저장 전에 적용한다.

### 12.2 credential 구조

- registry에는 `credential_ref = "vault://connector/account"`만 기록한다.
- OS keychain 사용 가능 여부와 age fallback을 명시적으로 health에 보여준다.
- plugin에는 원 credential 대신 가능한 경우 short-lived token 또는 capability handle을 전달한다.
- `exec` 환경 전체 상속을 기본으로 하지 않고 allowlist된 환경 변수만 구성한다.
- child process argv, current working directory, stdout/stderr에 credential이 들어가지 않게 한다.
- credential export/copy는 별도 high-risk action으로 분류하고 TTL clipboard clear는 보조책으로만 본다.
- revoke, rotate, last-used, granted scopes, account/tenant를 metadata로 보여주되 token fingerprint도 외부
  상관관계 위험이 있으면 저장하지 않는다.

### 12.3 권한 모델

개인용이어도 “사용자 한 명이므로 권한 모델이 필요 없다”는 결론은 위험하다. 실행 주체가 CLI,
Dashboard, scheduler, mobile approval, plugin, AI client로 늘어나기 때문이다.

**[제안]** 다음 세 축을 독립적으로 판단한다.

- **Capability:** read metadata, read content, draft, write, delete, execute, resolve secret.
- **Resource scope:** connector/account/project/repository/channel/calendar/path.
- **Invocation scope:** foreground once, session, scheduled, background persistent.

기본 deny, scope 증가 시 재승인, foreground 승인과 background grant 분리, connector disable 시 token revoke
guidance를 적용한다.

## 13. audit와 관찰 가능성

**[제안]** Activity history와 security audit를 분리한다.

- Activity: 사용자가 최근 흐름을 이해하기 위한 bounded projection.
- Audit receipt: 권한 판단과 mutation을 설명하는 append-only record.
- Diagnostic log: 오류 분석용이며 짧은 retention과 redaction을 적용.

audit에는 `time`, `actor surface`, `action type`, `target stable ID`, `plan hash`, `policy decision`,
`provider request ID`, `outcome`, `recovery hint`를 남긴다. message body, Secret, raw HTTP header, full path는
기본 제외한다. 수정·삭제 가능한 일반 UI와 별도로 hash chain 또는 periodic signed checkpoint를 검토할 수
있지만, 개인용 초기 단계에 과도한 tamper-evidence를 강제하지 않는다.

**[불확실]** 개인 사용에서 어느 정도의 장기 감사가 실제로 필요한지 알 수 없다. 30일/90일 같은 기간을
임의로 확정하지 말고 security event와 일상 activity의 사용 사례를 먼저 관찰해야 한다.

## 14. 백업·복구

### 14.1 위협별 복구 경로

| 실패 | 필요한 복구 |
|---|---|
| 잘못된 mutation | action 전 backup + inverse action 또는 provider-side undo |
| schema migration 실패 | pre-migration snapshot + 이전 binary + fail-closed |
| DB/파일 손상 | 검증된 snapshot restore + index rebuild |
| 장비 분실 | 암호화된 off-device backup + 별도 key recovery |
| credential 유출 | backup restore가 아니라 revoke/rotate |
| 외부 서비스 삭제/정지 | portable export, source-specific export, 대체 connector |
| 공급망 compromise | known-good release manifest와 artifact verification |

### 14.2 권장 운영 계약

- `wb backup create/list/verify/restore --dry-run`을 CLI 기준 경로로 둔다.
- backup manifest에 schema version, app version, 파일 hash, 생성 시각, 포함/제외 class를 기록한다.
- config/state와 Secret backup을 분리한다. age key는 암호문과 다른 위치에도 복구 가능하게 보관한다.
- restore는 새 임시 위치에서 decode/schema/checksum을 검증한 뒤 교체하고, 현재 상태도 다시 snapshot한다.
- 정기 backup보다 정기 restore drill을 성공 기준으로 삼는다.
- portable export에는 Secret과 external body를 기본 제외하고, 포함 시 별도 encrypted archive와 경고를 쓴다.
- Git은 선언·문서 history에 사용하되 runtime DB, token, age key, webhook URL은 commit하지 않는다.
- SQLite 도입 시 실행 중 DB backup은 Online Backup API 또는 `VACUUM INTO` 같은 지원 경로를 사용한다(S1).

**[제안]** 최소 목표는 “한 장비의 로컬 backup”이 아니라 암호화된 off-device 사본과 복구 절차다.
다만 특정 cloud backup 공급자를 제품 필수 dependency로 만들지 않는다.

## 15. 공급망 보안

### 위험

- 독립 5개 repo와 plugin/Go/npm 의존성의 version drift
- `bootstrap`/setup hook이 사용자 권한으로 실행하는 코드
- 최신 branch를 pull한 직후 검증 없이 실행하는 경로
- MCP server나 connector binary가 credential과 filesystem에 접근하는 위험
- GitHub Actions, release asset, package registry 계정 compromise

### 권고

1. `repos.lock`을 “관찰 snapshot”과 “검증된 release manifest” 중 하나로 명확히 정의한다.
2. release manifest라면 repo commit, Go module graph, npm lock, binary SHA-256, platform, 검증 결과를 묶는다.
3. bootstrap은 lock과 불일치할 때 report-only/deny 정책을 profile로 명시하고, dirty tree를 계속 보존한다.
4. 외부 plugin/MCP server는 source URL과 version/digest pin 없이는 background enable하지 않는다.
5. release binary에는 artifact attestation을 생성하고 소비 시 signer/repository/workflow/commit expectation을
   검증한다. attestation 생성만으로 안전해지는 것은 아니며 검증 정책이 필요하다(S13, S14).
6. dependency update는 자동 merge보다 diff, test, vulnerability/advisory 검토와 rollback commit을 남긴다.
7. CI token은 최소 권한·짧은 lifetime을 사용하고 untrusted PR에서 release credential을 노출하지 않는다.

**[사실]** SLSA 1.2는 build provenance와 단계적 build/source 보증을 정의하며, provenance가 artifact의
출처·빌드 과정을 추적하게 한다(S13). **[추론]** 개인용 프로젝트가 즉시 높은 SLSA level을 달성할
필요는 없지만, “어떤 commit을 어떤 workflow가 만들었는지 검증”하는 습관은 lock drift 문제에 직접
도움이 된다.

## 16. destructive action 안전 모델

### 16.1 위험 등급

| 등급 | 예 | 기본 gate |
|---|---|---|
| R0 관찰 | list, search, health | 자동 허용, 민감 범위 제한 |
| R1 가역 변경 | label, draft, local note | receipt + undo 정보 |
| R2 외부 쓰기 | Slack post, calendar update, send mail | plan/diff + 대상 확인 + idempotency |
| R3 파괴적/광범위 | delete, branch removal, Secret export, infra apply | foreground 재확인 + exact target 입력/강한 challenge |
| R4 대량·복구 곤란 | bulk delete, destroy, permission expansion | 기본 미제공 또는 별도 break-glass workflow |

### 16.2 공통 불변 조건

- action 직전 source를 다시 읽어 ID, revision/ETag, owner, path, dirty/locked 상태를 검증한다.
- UI가 보인 snapshot과 현재 상태가 다르면 stale plan을 거부한다.
- “yes”만 묻지 말고 대상, scope, 영향 수, 가역성, backup/undo, credential scope를 보여준다.
- bulk action은 selection set hash와 최대 건수를 고정한다.
- provider timeout 후 성공 여부가 불명확하면 재시도 전에 reconcile한다.
- 자동화와 AI client에는 destructive capability를 기본 부여하지 않는다.
- 실패가 partial이면 완료된 단계와 남은 복구를 분리해 보고한다.
- local delete와 remote delete, archive와 permanent delete를 다른 action type으로 둔다.

이 모델은 현행 worktree remove의 exact registry/path/branch/dirty 재검증과 managed Task만 stop하는 계약을
일반화한 것이다.

## 17. 단계별 기술 전략

### 단계 0 — 안전 기준선과 결정

목표: 새 integration 전에 기존 기반의 의미를 확정한다.

- Workbench required/optional/profile 정책과 지원 platform tier 결정
- `repos.lock` 의미 결정, 현재 drift 해소 절차 문서화
- 현행 config/state/Secret backup inventory와 실제 restore drill
- connector별 대상 account, 데이터 class, scope, 보존 요구 inventory
- macOS, Linux, WSL에서 CLI/Dashboard/Secret smoke

완료 조건: 어떤 데이터가 어디에 있고, core 없이 어떻게 복구하며, 어떤 binary 조합을 신뢰하는지
설명할 수 있다.

### 단계 1 — core contract 보강

목표: connector가 없어도 필요한 공통 안전 계약을 만든다.

- typed `ActionPlan/ActionRun`, idempotency, risk class, reconcile contract
- portable export/import와 `backup verify/restore --dry-run`
- credential reference와 capability/resource/invocation scope
- Activity와 audit receipt 분리
- schema migration fixture, crash/partial-write/concurrent-write test

이 단계에서는 범용 plugin process나 새 desktop 앱을 만들지 않는다.

### 단계 2 — local adapter 두 개

목표: network/auth 없이 데이터·검색·ownership 모델을 검증한다.

- filesystem 문서 index: owned root, ignore, sensitivity, rebuild
- Git projection: repository/worktree/branch/status/read-only history
- lexical search와 source/observed-at 표시
- adapter contract가 두 구현에서 반복되는 부분만 추출

완료 조건: index를 지우고 재구축할 수 있고, 외부/dirty 자원을 잘못 변경하지 않는다.

### 단계 3 — 캘린더 한 개 또는 좁은 Slack 송신

목표: 첫 OAuth/credential/rate-limit 또는 webhook Secret 경계를 실제로 검증한다.

- 사용 빈도가 높다면 calendar read + draft update를 우선
- 단순 알림 가치가 더 크다면 특정 channel Slack incoming webhook 송신만 우선
- polling/delta, cursor reset, scope escalation, revoke, export, connector disable 검증
- R2 action은 plan/diff와 foreground confirmation 유지

둘을 동시에 시작하지 않는다. 첫 connector의 성공 기준은 기능 수가 아니라 30일 동안 복구·권한·사용
근거가 쌓이는 것이다.

### 단계 4 — MCP management와 두 번째 서비스

목표: 반복 근거가 생긴 뒤 config·health control plane을 확장한다.

- 한 MCP server를 두 client에 catalog/config/health/disable/rollback
- client 설정은 owned block, backup, dry-run diff로 생성
- direct API adapter와 MCP server를 같은 권한으로 오인하지 않도록 provenance 표시
- 첫 두세 connector에서 확인된 contract만 external plugin protocol 후보로 승격

### 단계 5 — background sync와 보조 UI

목표: 사용 가치가 background 복잡성을 정당화할 때만 도입한다.

- durable queue, bounded retry, sleep/resume, network-offline test
- webhook relay는 polling latency가 실제 문제일 때만
- 모바일은 read-only/approval challenge로 제한
- OS keychain/tray/notification 때문에 필요할 때만 desktop thin shell 검토

## 18. 검증 계획

| 영역 | 필수 검증 |
|---|---|
| 데이터 | migration golden test, corrupt/truncated file, concurrent writer, crash injection |
| 검색 | Secret/ignored path 미색인, delete/rebuild, stale source 표시 |
| sync | duplicate/out-of-order/missed event, cursor expiry, full rescan, 429/5xx |
| 권한 | scope downgrade/revoke, wrong tenant/account, background grant expiry |
| OAuth | PKCE/state, loopback callback race, token log/argv 부재, refresh rotation |
| plugin | malformed/oversized output, timeout, crash, digest mismatch, forbidden domain/path |
| destructive | stale ETag, partial success, idempotent retry, bulk limit, exact target confirmation |
| backup | encrypted off-device copy, key unavailable, full restore on clean profile |
| 공급망 | lock verification, artifact attestation expectation, compromised dependency drill |
| platform | 실제 Linux/macOS/WSL smoke; cross-build와 분리 기록 |

## 핵심 결론

1. **[추론]** Setup의 local-first 개인 운영 환경 방향은 현행 Workbench 안전 계약과 잘 맞으며 기술적으로
   실현 가능하다.
2. **[제안]** core는 외부 서비스 원본을 대체하는 중앙 DB가 아니라 canonical metadata, 사용자 정책,
   ownership, action receipt를 소유해야 한다.
3. **[제안]** CLI를 복구 가능한 기준 인터페이스로 유지하고 Local Web UI를 조회·검색·승인 surface로
   강화한다. desktop과 mobile은 명확한 OS/원격 수요가 확인된 뒤다.
4. **[제안]** MCP는 여러 연동 방식 중 하나이며, 초기에는 catalog/config/health/access 관리에 한정한다.
   직접 API, 표준 protocol, file, Git을 용도에 맞게 함께 사용한다.
5. **[제안]** webhook은 local-first 기본 경로가 아니라 선택적 알림 가속기다. polling/delta와 reconciliation이
   복구 기준이어야 한다.
6. **[제안]** Secret reference, 최소 scope, managed/observed authority, typed action, stale-state revalidation,
   backup/restore drill을 모든 connector의 공통 불변 조건으로 삼는다.
7. **[제안]** 전면 SQLite 전환, 범용 plugin SDK, cloud relay, vector search보다 현재 lock·backup·audit·실장비
   검증의 빈틈을 먼저 메우는 것이 위험 대비 가치가 높다.

## 채택 권고

- 채택: hybrid local storage(사람이 복구할 선언 파일 + 필요 시 SQLite runtime store)
- 채택: `Item/SourceRef/Link/ActionRun/Connector`의 작은 공통 envelope
- 채택: trusted narrow adapter 우선, external subprocess plugin은 반복 수요 이후
- 채택: CLI → Local Web UI → mobile helper → 필요 시 desktop thin shell 순서
- 채택: polling/delta 기본, webhook optional accelerator
- 채택: credential reference와 capability/resource/invocation 3축 권한
- 채택: Activity와 audit receipt의 목적 분리
- 채택: action risk class, dry-run/diff, idempotency, reconcile, exact-target 재검증
- 채택: portable export, encrypted off-device backup, 정기 restore drill
- 채택: release manifest 의미의 lock, artifact provenance 생성과 소비 시 검증
- 보류: 범용 MCP proxy, 임의 command plugin, 항상 켜진 cloud state, CRDT sync, vector DB, 독립 desktop 앱

## 반론

1. **“한 DB와 한 UI로 빨리 통합해야 제품 가치가 보인다.”**
   관계형 조회와 UI 일관성은 좋아진다. 그러나 외부 원본의 authority와 복구 경로를 core가 흡수하면
   단일 장애 지점과 lock-in이 커진다. portable 선언과 projection DB의 혼합이 더 느려 보여도 실패 범위를
   작게 유지한다.

2. **“처음부터 plugin SDK를 만들면 connector 개발이 빨라진다.”**
   이미 반복되는 인증·sync·action 계약이 있다면 맞다. 현재는 대상 connector inventory조차 없어서
   추상화가 실제 차이를 왜곡할 가능성이 더 크다.

3. **“webhook이 polling보다 효율적이므로 기본이어야 한다.”**
   항상 공개 endpoint를 가진 서버라면 맞다. 개인 장비 local-first 환경에서는 endpoint, relay, sleep,
   subscription 만료와 누락 복구가 추가된다. webhook을 hint로 쓰고 polling/delta로 수렴하는 편이 견고하다.

4. **“MCP 하나로 API 연동을 통일할 수 있다.”**
   AI client의 tool 호출에는 유용하지만, 공급자 고유 sync cursor, rate limit, webhook lifecycle, export,
   offline cache를 자동으로 해결하지 않는다. MCP server도 별도 신뢰·권한·공급망 평가 대상이다.

5. **“개인용이므로 OS keychain과 audit는 과하다.”**
   사용자는 한 명이어도 scheduler, browser, AI client, plugin은 서로 다른 실행 주체다. 다만 조직용 RBAC와
   장기 SIEM을 복제할 필요는 없으며 작은 capability grant와 metadata receipt면 시작할 수 있다.

6. **“모바일/desktop 앱이 있어야 통합 도구처럼 느껴진다.”**
   접근성은 높아지지만 배포·서명·업데이트·원격 공격면을 먼저 떠안는다. 기존 CLI와 Local Web UI에서
   반복 사용을 증명한 뒤 thin client를 추가해도 늦지 않다.

## 불확실성

- 첫 실제 connector가 calendar, mail, Slack, Teams, MCP 중 무엇이어야 하는지는 일상 사용 빈도 자료가 없다.
- 캘린더/메일 provider와 account 종류가 없어 CalDAV/JMAP/IMAP과 vendor API의 실제 적합도를 확정할 수 없다.
- Workbench registry의 크기, 검색 문서 수, 동시 writer 수가 측정되지 않아 SQLite 도입 시점을 정할 수 없다.
- macOS keychain, Windows Credential Manager, Linux Secret Service/age fallback의 목표 지원 조합이 정해지지 않았다.
- 모바일 접근이 LAN/VPN만 필요한지, 인터넷 relay가 필요한지 알 수 없다.
- webhook latency가 polling보다 유의미한 사용자 가치를 주는지 증거가 없다.
- 개인 audit 보존 기간과 tamper-evidence 수준에 대한 요구가 없다.
- 실제 장비 smoke와 장기간 scheduler 안정성은 아직 증명되지 않았다.
- 외부 서비스의 2026-08-10 이후 API, rate limit, MCP 규격 변경 가능성이 있다. 구현 직전에 다시 확인해야 한다.

## 출처

모든 외부 URL은 **2026-08-10 확인**했다. 저장소 내부 근거는 같은 날짜의 현재 checkout을 기준으로 한다.

- **S1. SQLite, Online Backup API** — 실행 중 DB의 일관된 snapshot과 backup 방식.
  https://www.sqlite.org/backup.html
- **S2. SQLite, Write-Ahead Logging** — WAL 동반 파일, checkpoint와 durability 특성.
  https://www.sqlite.org/wal.html
- **S3. Model Context Protocol, Authorization (2025-11-25 규격)** — OAuth, resource audience,
  token validation과 token passthrough 금지.
  https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
- **S4. Model Context Protocol, Security Best Practices** — session, token, confused deputy 등 MCP 위협과 완화.
  https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices
- **S5. IETF RFC 8252, OAuth 2.0 for Native Apps** — public client, system browser, PKCE와 loopback redirect.
  https://www.rfc-editor.org/info/rfc8252/
- **S6. IETF RFC 9700 / BCP 240, Best Current Practice for OAuth 2.0 Security** — 최신 OAuth 위협과 완화.
  https://www.rfc-editor.org/info/rfc9700/
- **S7. Slack, Sending messages using incoming webhooks** — channel-bound webhook URL, Secret 취급과 기능 제한.
  https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks
- **S8. Microsoft Graph, lifecycle events for change notifications** — subscription 재인가·삭제·누락과 복구.
  https://learn.microsoft.com/en-us/graph/change-notifications-lifecycle-events
- **S9. Slack, Web API rate limits** — `429`와 `Retry-After`, method/workspace 단위 제한.
  https://docs.slack.dev/apis/web-api/rate-limits/
- **S10. Slack, Web API** — OAuth bearer token, HTTPS와 API 호출 계약.
  https://docs.slack.dev/apis/web-api/
- **S11. IETF RFC 4791, CalDAV** — WebDAV 기반 calendar access 표준.
  https://www.rfc-editor.org/info/rfc4791/
- **S12. IETF RFC 8620, JMAP Core** — 동기화 가능한 데이터 유형과 JMAP core protocol.
  https://www.rfc-editor.org/info/rfc8620/
- **S13. SLSA Specification v1.2** — build/source track, 단계적 공급망 보증과 provenance.
  https://slsa.dev/spec/v1.2/
- **S14. GitHub Docs, Artifact attestations** — build provenance 생성과 검증, 검증 정책의 필요성.
  https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations

### 저장소 내부 근거

- `README.md`, `plan/PRODUCT-PLAN.md`, `plan/README.md`, `plan/raw/*.md`
- `workbench/README.md`
- `workbench/docs/backend-contract.md`
- `workbench/docs/dashboard.md`
- `workbench/docs/secrets.md`
- `workbench/docs/tasks.md`
- `workbench/docs/workflows.md`
- `workbench/docs/worktrees.md`
