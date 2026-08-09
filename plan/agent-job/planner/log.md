# Product planner 작업 로그

## 2026-08-10 08:21 KST — Phase 0 Dashboard specification

### 작업

- 현행 제품 계획과 raw synthesis/current-system/user-scenario 자료를 검토했다.
- Workbench Dashboard 문서, backend/Agent/worktree 계약, Design 문서와 embedded Dashboard route/action assets를
  구현 기준선으로 확인했다.
- operations console을 유지하면서 목표 IA와 화면 상태, 반응형·접근성, Core/API, no-second-state-owner,
  typed mutation safety, 단계별 deliverable/acceptance test를 `plan/DASHBOARD-SPEC.md`에 작성했다.
- 제품 계획과 plan index에는 필요한 결정과 링크만 추가하고 raw synthesis에 날짜가 있는 addendum을 남겼다.

### 가정

- `DASHBOARD-SPEC.md`의 v2 route/envelope/action 이름은 Phase 0 target contract이며 현재 구현 완료 상태가 아니다.
- iTerm2는 확정된 native fallback 방향이지만 현 Workbench backend 구현에는 없으므로 구현·실장 smoke 전에는
  unavailable capability로 표시한다.
- 현재 v1 route/action은 안전 계약과 deep link를 보존한 compatibility 단계 뒤에만 이행한다.
- Orca는 기본 workspace/runtime owner지만 Workbench의 장기 project/task/ref/run index를 대신 소유하지 않는다.

### 검토 질문

- backend RFC에서 v2 area query를 여러 endpoint로 나눌지, schema-v1 snapshot 안에서 먼저 additive하게
  제공할지 결정해야 한다.
- canonical Markdown 최소 frontmatter와 rename/revision 규칙은 별도 schema prototype에서 확정해야 한다.
- Orca worktree와 human tmux partition의 stable link field 및 iTerm2 capability contract는 backend owner와
  fixture를 합의해야 한다.
- current destructive v1 actions 중 어느 것을 새 IA에 재노출할지는 각 phase ownership gate에서 재검토한다.

### 변경 파일

- `plan/DASHBOARD-SPEC.md`
- `plan/PRODUCT-PLAN.md`
- `plan/README.md`
- `plan/raw/synthesis-and-decisions.md`
- `plan/agent-job/planner/log.md`

### validation

- branch가 `orca/work`인지 확인했다.
- planner-owned `plan/` 문서만 변경하고 Workbench frontend/backend/PM-owned 구현 파일은 수정하지 않았다.
- `git diff --check`가 통과했다.
- 문서 link target이 존재하고 핵심 결정 문구와 Markdown heading 구조가 포함됐는지 검사했다.

### 다음 단계

1. PM이 Phase 0 범위와 성공 지표의 일관성을 검토한다.
2. backend owner가 Markdown/projection schema와 shared Core query/action RFC를 작성한다.
3. frontend owner가 current v1 compatibility map을 기준으로 navigation shell과 공통 상태 component를 설계한다.
4. QA/접근성 owner가 Phase 1 viewport, keyboard, screen reader와 security fixture를 test plan으로 변환한다.
