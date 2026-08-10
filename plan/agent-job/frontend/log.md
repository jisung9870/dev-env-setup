# Frontend agent log

## 2026-08-10 — S0 Dashboard compatibility baseline

### Scope and ownership

- Owned only `workbench/docs/dashboard-compatibility.md` and this log.
- Did not change runtime UI, embedded assets, Go handlers/services, tests, target
  schemas, planner/PM/backend documents, commits, or branches.
- Both root and nested Workbench checkouts were on `orca/work`; evidence commits
  were root `63e22fabafcce4adf7f2429a5038749c2ad40519` and Workbench
  `10347a9d169a2cb7fa69dd03e174437cb47d192e`.

### Evidence reviewed

- `plan/DASHBOARD-SPEC.md`, `plan/ARCHITECTURE.md`, and
  `plan/IMPLEMENTATION-ROADMAP.md`.
- `workbench/docs/dashboard.md`, `workbench/docs/backend-contract.md`, and the
  concurrently delivered backend `workbench/docs/core-contract-baseline.md` plus
  `plan/agent-job/backend/log.md`.
- `workbench/internal/dashboard/assets/index.html`, `app.js`, `style.css`, theme
  and Guide assets.
- `workbench/internal/dashboard/dashboard.go`, `dashboard_test.go`, Node
  `testdata/*.mjs`, `workbench/internal/cli/dashboard.go`, and
  `dashboard_test.go`.

### Findings recorded

- Mapped every current route and all 15 top-level v1 action IDs to one of Today,
  Inbox, Projects, Runs & Agents, Integrations, or System & Recovery, with
  compatibility hold/alias decisions and current/planned language.
- Recorded that route-only deep links exist; selected Project/Task is
  browser-memory-only and periodic full rerenders can replace focused controls.
- Inventoried DOM-rendered local-sensitive fields, existing Secret/redaction
  boundaries, common-state behavior, accessibility gaps, responsive behavior at
  360/768/1280, and absent executable browser coverage.
- Defined S1–S3 frontend seams, fixtures, browser/Node/Go checks, zero-overlap
  file-owner boundaries, uncertainties, and non-goals without defining target API
  fields.
- Sent the coordinator an Orca status message about the unresolved action-body
  limit mismatch and the initially absent backend S0 artifact; after the
  coordinator routed the completed backend baseline, reconciled its 15-action,
  service-boundary, partial-state, redaction, and file-owner findings here.

### Validation completed

- `go test ./...` passed for the Workbench module.
- `go test ./internal/dashboard ./internal/cli` passed.
- `node --check` passed for `app.js`, `theme.js`, and `guide.js`; `node --test
  internal/dashboard/testdata/*.mjs` passed 9/9.
- New-file `git diff --no-index --check`, relative Markdown link validation,
  ownership/status checks, and final diff review passed.

## 2026-08-10 — S1 focus-safe six-area compatibility shell

### Scope and implementation

- Changed only the embedded Dashboard HTML/JavaScript/CSS, frontend Node
  fixtures, and this log; no handler, service, API, route, target-schema,
  commit, or branch changes were made by the frontend owner.
- Reframed the primary navigation as Today (`/`), Projects (`/projects`), Runs
  & Agents (`/activity`), Integrations (`/settings`), and System & Recovery
  (`/system`) while keeping Guide separate. Inbox is a focusable non-link with
  `aria-disabled="true"` and explicit “requires S2” help text; no `/inbox`,
  `/runs`, or v2 URL was introduced.
- Kept `/activity` and `/settings` as rendered compatibility pages and retained
  current profile, context, Secret, agent, workflow, terminal, and recovery
  controls. Added stable route headings, snapshot status, and a persistent
  fixed-copy error summary whose optional code is allowlisted rather than
  rendering backend messages or sensitive values.
- Captured focus by exact stable `id`, existing data identity, details owner,
  or form/control name before the 15-second refresh and action reload. Restore
  accepts only the same connected, enabled, visible control; otherwise it
  focuses the visible route heading with a polite notice and never chooses a
  neighboring action or creates another owner for Project/Task selection.
- Added narrow-shell reflow, horizontal navigation overflow, 44 px interactive
  targets, and 16 px form controls for zoom/mobile compatibility without
  hiding the planned Inbox semantics.

### Contract and peer review

- Reviewed the concurrent backend diff: it preserves all current Dashboard and
  Guide routes plus all 15 v1 action shapes, rejects target `/today`, `/inbox`,
  `/runs`, `/integrations`, and v2 paths, and implements the accepted exact
  16,384-byte action boundary with `ACTION_REQUEST_TOO_LARGE` redaction.
- The frontend continues to post only existing v1 payloads and uses only the
  existing snapshot fields. Failure UI displays the allowlisted error code and
  fixed frontend copy, so the backend's non-echo contract is not weakened in
  the DOM.

### Validation and evidence boundary

- `node --check internal/dashboard/assets/app.js` passed; `node --test
  internal/dashboard/testdata/*.mjs` passed 20/20, including exact focus
  restore, removed/disabled/hidden/`aria-disabled` fallback, non-sensitive
  identities, refresh/action wiring, six-area order/destinations, Inbox
  semantics, persistent failure structure, and narrow CSS assertions.
- `go test ./internal/dashboard ./internal/cli`, `go test ./...`, `go vet ./...`,
  and `go build ./cmd/wb` passed with the shared backend changes present.
- Static HTML/CSS/Node evidence covers the 360/768/1280 and 200% compatibility
  rules, but this checkout has no executable real-browser viewport/zoom harness;
  keyboard traversal, visual clipping, scroll position, and focus-ring capture
  at those widths remain an explicit validation-owner evidence gap rather than
  a claimed pass.

## 2026-08-10 — S1 Inbox focus acceptance correction

### Conditional-gate resolution

- Reviewed the conditional acceptance and dissent in `DASHBOARD-SPEC.md`, the
  planner log, and the PM checkpoint records. The accepted contract makes Inbox
  unavailable for activation while intentionally keeping its native button in
  the keyboard order, so `aria-disabled="true"` must not itself make that same
  present control unavailable for focus restoration.
- Removed the ARIA-disabled check from the restore-unavailable predicate.
  Removed nodes, native `disabled` controls, the `hidden` attribute/ancestor,
  and CSS-hidden/no-box controls still fall back to the visible route heading
  with the fixed polite notice; no adjacent or destructive control is selected.
- Inbox retains its existing `aria-disabled` semantics and notice-only click
  handler. No route, action, API field, selection owner, handler, or backend
  behavior changed.

### Regression and validation

- Replaced the contrary Inbox fixture with a rerender regression that captures
  the old Inbox identity, replaces the DOM node with a present ARIA-disabled
  Inbox button, and proves exact restoration with no removal notice. The
  fallback matrix separately covers removed, native-disabled, hidden-attribute,
  and CSS-hidden targets plus destructive-neighbor avoidance.
- `node --check internal/dashboard/assets/app.js` passed and all frontend Node
  fixtures passed 20/20. `go test ./...`, `go vet ./...`, and
  `go build ./cmd/wb` also passed.
- This closes the planner's source/fixture Inbox predicate dissent. The earlier
  real-browser route, actual lifecycle, keyboard, accessibility-tree, viewport,
  and zoom evidence gap remains unchanged and is not claimed as completed here.
