# Backend agent job log

## 2026-08-10 — task `task_80f0fdc7d816`

> Dispatch: `ctx_58ee06c3c59b`.

### Work

- Read the Phase 0 architecture, Dashboard specification, implementation roadmap, current Dashboard contract, and the Go Dashboard/CLI/server/store/runtime implementations and tests.
- Created `workbench/docs/core-contract-baseline.md` as the S0 evidence inventory and S1–S3 backend change map without implementing target v2 fields or Orca mutation.
- Inventoried current snapshot/action owners, persisted versus rebuildable state, runtime ownership, security/compatibility invariants, gaps, proposed service boundaries, fixtures, validation commands, uncertainties, and non-goals.
- Mapped all 15 executable Dashboard action IDs to current owner, canonical target owner/area, risk, status, and migration gate.

### Findings

- The current HTTP `dashboard.Service` is narrow, but its production `dashboardService` lives in `internal/cli` and directly composes domain managers. CLI and Dashboard reuse packages but do not yet share a client-neutral ActionPlan/ActionRun application service.
- `update_secret` exists in code and tests but is absent from the 14-row public action table, so the executable action baseline is 15.
- The public Dashboard document says a 16 KiB action limit while `maxActionBody` is approximately 16 MiB plus 64 KiB. This is recorded as an S1 security/compatibility decision, not silently “fixed” in documentation.
- Current Workbench Agent/session lifecycle mutations remain compatibility behavior. Target ownership belongs to Orca, but read/open/jump waits for S4B, controlled launch waits for S8, and stop/remove has no approved target stage.
- Workflow and activity histories are bounded (50 and 200 respectively); current JSON persistence cannot be labeled a durable C2/O1 journal or rebuildable projection without an S2 classification/replay design.

### Coordination

- Sent the coordinator a status finding through Orca orchestration describing the 15-action discrepancy and the lack of a shared application service.
- Reviewed the frontend-owned `workbench/docs/dashboard-compatibility.md` without editing it and sent concrete feedback to dispatch `ctx_1b6a2ffcb837`: separate canonical authority owner from target navigation area; treat environment state as Workbench Core context policy surfaced across Projects/Integrations; distinguish S3 non-Agent recipe plan/receipt adaptation from S8 Agent/worktree launch; and state that no current threshold test resolves the 16 KiB versus 16 MiB+64 KiB inconsistency.
- Backend resolution is recorded in the baseline action map, which has separate “current owner” and “canonical target owner / target area” columns and gates Agent/worktree execution at S8. The request-limit value remains explicitly unresolved for S1 rather than being normalized by either peer.
- No blocking decision was required; remaining questions are explicitly listed for the appropriate S1, S2, S3, or S4B gate.

### Files

- `workbench/docs/core-contract-baseline.md` — created.
- `plan/agent-job/backend/log.md` — created.

### Validation

- Passed `go test ./...`, `go vet ./...`, and `go build ./cmd/wb` from `workbench/`.
- Passed whitespace checks, owned-file diff review, and local Markdown link target validation.
- Root and nested branches were both `orca/work`; the working trees were clean before this task.

### Next steps

1. Coordinator/backend reviewers accept or revise the S0 classification and application-service boundaries.
2. Root owner supplies S1 verified-manifest/recovery input; backend consumes it read-only.
3. Backend prototypes S2 Markdown/O1 journal/projection fixtures without freezing frontend fields independently.
4. S3 extracts shared query/command services and adapts v1 only after the S2 data gate.

## 2026-08-10 08:52 KST — task `task_a7efcdcf003e`

> Dispatch: `ctx_45b3230277bc`.

### Implementation

- Accepted the S1 compatibility-lock decision in the roadmap and Dashboard specification and re-read both S0 backend/frontend baselines.
- Changed the complete authenticated `POST /api/v1/actions` JSON-body maximum from the accidental approximately 16 MiB+64 KiB value to exactly 16 KiB (16,384 bytes).
- The handler now bounded-reads the complete body before JSON decoding. Any 16,385-byte-or-larger body returns HTTP 413 with stable code `ACTION_REQUEST_TOO_LARGE`, fixed safe message `dashboard action request exceeds 16,384 bytes`, empty details, and no call to `Service.Execute`.
- Preserved authorization/origin and content-type ordering, unknown-field rejection, trailing-value rejection, schema-v1 envelopes, and the existing action request shapes.
- Updated the public Dashboard contract to enumerate all 15 executable v1 actions, including `update_secret`, and to state the exact total-body boundary and pre-execution rejection behavior.

### Tests and evidence

- Added exact threshold fixtures: a valid 16,384-byte request executes once; valid-plus-whitespace and malformed 16,385-byte requests both return the same safe 413 response without echoing body or decoder diagnostics and without execution.
- Added GET/HEAD regression coverage for all current page/Guide aliases and explicit 404 checks for unimplemented Today/Inbox/Runs/Integrations/v2 routes.
- Added transport fixtures for all 15 current action request shapes and a trailing-JSON-value regression alongside the existing unknown-field and token/origin tests.
- Passed the focused `internal/dashboard` suite, focused compatibility tests, `go test ./...`, `go vet ./...`, and `go build ./cmd/wb`.

### Peer review

- Frontend implementation peer is dispatch `ctx_b0a4e703e581`; file ownership remains disjoint.
- Sent the accepted HTTP contract proactively: HTTP 413, `ACTION_REQUEST_TOO_LARGE`, fixed allowlisted message, empty details, no v2 routes, unchanged v1 action payloads, and authorization/content-type precedence.
- Reviewed the visible frontend `index.html`/`app.js` changes without editing them. They stay on current v1 routes and payloads, parse the schema-v1 envelope, accept the stable oversized-request code, ignore backend message/details in favor of generic safe recovery text, and do not automatically retry the failed action.
- Requested a Node HTTP 413 fixture with hostile message/details to prove only `ACTION_REQUEST_TOO_LARGE` and generic recovery reach the DOM. No backend API conflict or shared-file overlap was found.
- Combined validation exposed one backend-owned test that coupled to HTML attribute order after the frontend added a stable `tmux-observer` ID. Updated the assertion to check the ID and `session-observer` class independently; no production contract change was needed.

### Files

- `workbench/internal/dashboard/dashboard.go`
- `workbench/internal/dashboard/dashboard_test.go`
- `workbench/docs/dashboard.md`
- `plan/agent-job/backend/log.md`
