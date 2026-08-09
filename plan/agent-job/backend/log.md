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
