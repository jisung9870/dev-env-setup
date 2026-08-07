#!/usr/bin/env bash

set -euo pipefail

WB="${WB_BINARY:-$HOME/.local/bin/wb}"
RUN_DIR="${1:-}"
[ -x "$WB" ] || { printf 'installed wb not executable: %s\n' "$WB" >&2; exit 1; }
[ -n "$RUN_DIR" ] && [ -d "$RUN_DIR/.wb-e2e-owned" ] || {
  printf 'refusing E2E without an owned run directory sentinel: %s/.wb-e2e-owned\n' "$RUN_DIR" >&2
  exit 2
}

export XDG_CONFIG_HOME="$RUN_DIR/config"
export XDG_STATE_HOME="$RUN_DIR/state"
export APPDATA="$RUN_DIR/config-windows"
export LOCALAPPDATA="$RUN_DIR/state-windows"
export FAKE_TMUX_STATE="$RUN_DIR/fake-tmux"
export PATH="$RUN_DIR/bin:/Applications/cmux.app/Contents/Resources/bin:$PATH"
export TMUX=""
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$APPDATA" "$LOCALAPPDATA" "$FAKE_TMUX_STATE" "$RUN_DIR/bin" "$RUN_DIR/projects"

dashboard_pid=""
cleanup() {
  if [ -n "$dashboard_pid" ] && kill -0 "$dashboard_pid" 2>/dev/null; then
    kill -INT "$dashboard_pid" 2>/dev/null || true
    wait "$dashboard_pid" 2>/dev/null || true
  fi
  if [ -f "$FAKE_TMUX_STATE/hung-child.pid" ]; then
    child_pid="$(cat "$FAKE_TMUX_STATE/hung-child.pid")"
    case "$child_pid" in *[!0-9]*|'') ;; *) kill "$child_pid" 2>/dev/null || true ;; esac
  fi
}
trap cleanup EXIT

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf '[E2E PASS] %s\n' "$1"; }
die() { printf '[E2E FAIL] %s\n' "$1" >&2; exit 1; }
expect_exit() {
  expected="$1"; shift
  set +e
  "$@" >"$RUN_DIR/last.stdout" 2>"$RUN_DIR/last.stderr"
  actual=$?
  set -e
  [ "$actual" -eq "$expected" ] || die "expected exit $expected, got $actual: $*"
}

cat >"$RUN_DIR/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -u
state="${FAKE_TMUX_STATE:?}"
mkdir -p "$state"
case "${1:-}" in
  -V)
    if [ "${FAKE_TMUX_MODE:-}" = hung ]; then
      sleep 5 &
      child=$!
      printf '%s\n' "$child" >"$state/hung-child.pid"
      wait "$child"
    else
      printf 'tmux 3.6-test\n'
    fi
    ;;
  has-session) exit 1 ;;
  new-session)
    if [ "${FAKE_TMUX_MODE:-}" = misleading ]; then
      printf 'SUCCESS but provider failed\n'
      exit 7
    fi
    ;;
  new-window) printf '%%42\n' ;;
  set-option)
    if [ "${5:-}" = '@workbench_task_id' ]; then
      printf '%s\n' "${6:-}" >"$state/pane-task"
    fi
    ;;
  display-message) cat "$state/pane-task" ;;
  attach-session|switch-client) printf 'jumped\n' ;;
  kill-pane) printf 'killed\n' >"$state/killed" ;;
esac
TMUX
cat >"$RUN_DIR/bin/codex" <<'CODEX'
#!/bin/sh
exit 0
CODEX
cat >"$RUN_DIR/bin/claude" <<'CLAUDE'
#!/bin/sh
exit 0
CLAUDE
chmod +x "$RUN_DIR/bin/tmux" "$RUN_DIR/bin/codex" "$RUN_DIR/bin/claude"

project="$RUN_DIR/projects/한글 project"
mkdir -p "$project"
git -C "$project" init -q -b main
printf 'fixture\n' >"$project/README.md"
git -C "$project" add README.md
git -C "$project" -c user.name='Workbench E2E' -c user.email=workbench@example.invalid commit -q -m initial

"$WB" projects add "$project" --id alpha --profile personal >/dev/null
"$WB" projects list --json >"$RUN_DIR/projects.json"
python3 - "$RUN_DIR/projects.json" "$project" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["schema_version"] == 1 and data["ok"]
projects = data["data"]["projects"]
assert len(projects) == 1 and projects[0]["id"] == "alpha"
assert projects[0]["path"] == os.path.realpath(sys.argv[2])
PY
pass 'installed binary project add/list with Unicode and spaces'

marker="$RUN_DIR/argv-injection-marker"
hostile_path="$RUN_DIR/projects/\$(touch argv-injection-marker)"
mkdir -p "$hostile_path"
"$WB" projects add "$hostile_path" --id hostile >/dev/null
expect_exit 2 "$WB" projects add "$project" --id "bad;touch-$marker"
[ ! -e "$marker" ] || die 'project ID was shell-interpolated'
"$WB" projects remove hostile >/dev/null
[ -d "$hostile_path" ] || die 'registry removal deleted hostile-path directory'
pass 'hostile IDs and argv-like paths are not shell-interpolated'

bad_root="$RUN_DIR/bad-state"
mkdir -p "$bad_root/config/workbench" "$bad_root/state"
printf 'schema_version = 1\nunknown = true\n' >"$bad_root/config/workbench/config.toml"
expect_exit 2 env XDG_CONFIG_HOME="$bad_root/config" XDG_STATE_HOME="$bad_root/state" APPDATA="$bad_root/config" LOCALAPPDATA="$bad_root/state" "$WB" config validate
mkdir -p "$bad_root/state/workbench"
printf '{not-json\n' >"$bad_root/state/workbench/agents.json"
expect_exit 1 env XDG_CONFIG_HOME="$bad_root/empty-config" XDG_STATE_HOME="$bad_root/state" APPDATA="$bad_root/empty-config" LOCALAPPDATA="$bad_root/state" "$WB" agents list --json
pass 'malformed config and corrupted state fail closed'

sessionizer="$RUN_DIR/sessionizer"
mkdir -p "$sessionizer/parent/beta space" "$sessionizer/direct"
printf '%s\n=%s\n%s\n' "$sessionizer/parent" "$sessionizer/direct" "$sessionizer/dead" >"$sessionizer/dirs"
registry_before_check="$(cksum "$XDG_CONFIG_HOME/workbench/projects.toml")"
backups_before_check="$(find "$XDG_STATE_HOME/workbench/backups" -type f -print 2>/dev/null | sort || true)"
"$WB" migrate sessionizer --check --file "$sessionizer/dirs" >"$RUN_DIR/migrate-check.txt"
[ "$(cksum "$XDG_CONFIG_HOME/workbench/projects.toml")" = "$registry_before_check" ] || die 'migration check changed the project registry'
[ "$(find "$XDG_STATE_HOME/workbench/backups" -type f -print 2>/dev/null | sort || true)" = "$backups_before_check" ] || die 'migration check created a backup'
"$WB" migrate sessionizer --apply --file "$sessionizer/dirs" >"$RUN_DIR/migrate-apply.txt"
grep -E '^(sessionizer source:|projects to add:|[+=] )' "$RUN_DIR/migrate-check.txt" >"$RUN_DIR/migrate-check-plan.txt"
grep -E '^(sessionizer source:|projects to add:|[+=] )' "$RUN_DIR/migrate-apply.txt" >"$RUN_DIR/migrate-apply-plan.txt"
cmp "$RUN_DIR/migrate-check-plan.txt" "$RUN_DIR/migrate-apply-plan.txt" || die 'migration check/apply plans diverged'
source_backup="$(awk '/^backup / {print $2; exit}' "$RUN_DIR/migrate-apply.txt")"
[ -f "$source_backup" ] || die 'migration apply did not create the reported source backup'
cmp "$sessionizer/dirs" "$source_backup" || die 'migration source backup differs from the source'
"$WB" migrate sessionizer --apply --file "$sessionizer/dirs" >"$RUN_DIR/migrate-repeat.txt"
"$WB" projects list --json >"$RUN_DIR/projects-after-migrate.json"
python3 - "$RUN_DIR/projects-after-migrate.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
ids = {item["id"] for item in data["data"]["projects"]}
assert "alpha" in ids and len(ids) == 3
PY
grep -qi 'skip\|unchanged\|already\|no changes' "$RUN_DIR/migrate-repeat.txt" || die 'migration rerun did not report idempotence'
pass 'sessionizer check/apply/reapply preserves backup and idempotence'

"$WB" worktrees create alpha feature/e2e --base HEAD >/dev/null
"$WB" worktrees list alpha --json >"$RUN_DIR/worktrees.json"
read -r worktree_id worktree_path < <(python3 - "$RUN_DIR/worktrees.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
item = data["data"]["worktrees"][0]
print(item["id"], item["path"])
PY
)
printf 'dirty\n' >"$worktree_path/dirty.txt"
expect_exit 4 "$WB" worktrees remove "$worktree_id"
rm "$worktree_path/dirty.txt"
"$WB" worktrees remove "$worktree_id" >/dev/null
[ ! -d "$worktree_path" ] || die 'clean managed worktree remained after removal'
git -C "$project" show-ref --verify --quiet refs/heads/feature/e2e || die 'safe worktree removal deleted branch'
pass 'worktree lifecycle refuses dirty removal and preserves branch'

"$WB" agents start alpha --agent codex --backend tmux >"$RUN_DIR/agent-start.txt"
task_id="$(awk 'NR==1 {print $2}' "$RUN_DIR/agent-start.txt")"
case "$task_id" in task-*) ;; *) die "invalid task ID: $task_id" ;; esac
"$WB" agents list --project alpha --json >"$RUN_DIR/agents.json"
python3 - "$RUN_DIR/agents.json" "$task_id" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
tasks = data["data"]["agents"]
assert len(tasks) == 1 and tasks[0]["id"] == sys.argv[2]
assert tasks[0]["state"] == "running" and tasks[0]["state_source"] == "registry"
PY
printf 'wrong-owner\n' >"$FAKE_TMUX_STATE/pane-task"
expect_exit 4 "$WB" agents jump "$task_id"
printf '%s\n' "$task_id" >"$FAKE_TMUX_STATE/pane-task"
"$WB" agents jump "$task_id" >/dev/null
"$WB" agents stop "$task_id" >/dev/null
[ -f "$FAKE_TMUX_STATE/killed" ] || die 'agent stop did not target registered pane'
pass 'Agent registry enforces pane ownership across start/list/jump/stop'

expect_exit 1 env FAKE_TMUX_MODE=misleading "$WB" open alpha --backend tmux
grep -Fq 'SUCCESS but provider failed' "$RUN_DIR/last.stdout" || die 'misleading provider fixture did not execute'
pass 'SUCCESS-looking output with non-zero exit remains failure'

FAKE_TMUX_MODE=hung python3 - "$WB" <<'PY'
import os, subprocess, sys, time
started = time.monotonic()
result = subprocess.run([sys.argv[1], "doctor", "--json"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=os.environ.copy())
elapsed = time.monotonic() - started
assert result.returncode in (0, 1), (result.returncode, result.stderr.decode())
assert elapsed < 4.0, elapsed
PY
if [ -f "$FAKE_TMUX_STATE/hung-child.pid" ]; then
  hung_pid="$(cat "$FAKE_TMUX_STATE/hung-child.pid")"
  kill "$hung_pid" 2>/dev/null || true
fi
pass 'hung descendant-held pipe returns within bounded wall clock'

start_dashboard() {
  port="$1"
  : >"$RUN_DIR/dashboard.log"
  "$WB" dashboard --open none --port "$port" >"$RUN_DIR/dashboard.log" 2>&1 &
  dashboard_pid=$!
  for _ in $(seq 1 100); do
    dashboard_url="$(awk '/^URL: / {print $2; exit}' "$RUN_DIR/dashboard.log")"
    [ -z "$dashboard_url" ] || return 0
    kill -0 "$dashboard_pid" 2>/dev/null || die 'dashboard exited before publishing URL'
    sleep 0.05
  done
  die 'dashboard URL was not published'
}

start_dashboard 0
curl -fsS "$dashboard_url" >"$RUN_DIR/dashboard-index.html"
token="$(sed -n 's/.*name="workbench-token" content="\([^"]*\)".*/\1/p' "$RUN_DIR/dashboard-index.html")"
[ -n "$token" ] || die 'dashboard action token missing'
curl -fsS "${dashboard_url}api/v1/snapshot" >"$RUN_DIR/dashboard-snapshot.json"
python3 - "$RUN_DIR/dashboard-snapshot.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ok"] and data["schema_version"] == 1
PY
origin="${dashboard_url%/}"
status="$(curl -sS -o "$RUN_DIR/dashboard-forbidden.json" -w '%{http_code}' -H 'Content-Type: application/json' -d '{"action":"open_project","project_id":"alpha"}' "${dashboard_url}api/v1/actions")"
[ "$status" = 403 ] || die "missing-token action returned $status"
status="$(curl -sS -o "$RUN_DIR/dashboard-origin.json" -w '%{http_code}' -H 'Content-Type: application/json' -H "X-Workbench-Token: $token" -H 'Origin: http://attacker.invalid' -d '{"action":"open_project","project_id":"alpha"}' "${dashboard_url}api/v1/actions")"
[ "$status" = 403 ] || die "cross-origin action returned $status"
python3 - <<'PY' >"$RUN_DIR/oversized.json"
print('{"action":"' + ('x' * 17000) + '"}')
PY
status="$(curl -sS -o "$RUN_DIR/dashboard-oversized-response.json" -w '%{http_code}' -H 'Content-Type: application/json' -H "X-Workbench-Token: $token" -H "Origin: $origin" --data-binary "@$RUN_DIR/oversized.json" "${dashboard_url}api/v1/actions")"
[ "$status" = 400 ] || die "oversized action returned $status"
for _ in 1 2 3 4 5; do curl -fsS "${dashboard_url}api/v1/snapshot" >/dev/null; done
dashboard_port="$(python3 - "$dashboard_url" <<'PY'
import sys, urllib.parse
print(urllib.parse.urlparse(sys.argv[1]).port)
PY
)"
kill -INT "$dashboard_pid"
wait "$dashboard_pid"
dashboard_pid=""
start_dashboard "$dashboard_port"
curl -fsS "$dashboard_url" >/dev/null
kill -INT "$dashboard_pid"
wait "$dashboard_pid"
dashboard_pid=""
pass 'Dashboard loopback auth/origin/body-limit/repeated-read/shutdown/restart'

"$WB" doctor --json >"$RUN_DIR/doctor.json"
python3 - "$RUN_DIR/doctor.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["schema_version"] == 1
assert data["data"]["summary"]["unavailable_core"] == 0
PY
projects_mode="$(stat -f '%Lp' "$XDG_CONFIG_HOME/workbench/projects.toml")"
agents_mode="$(stat -f '%Lp' "$XDG_STATE_HOME/workbench/agents.json")"
[ "$projects_mode" = 600 ] && [ "$agents_mode" = 600 ] || die "state permissions are projects=$projects_mode agents=$agents_mode"
"$WB" projects remove alpha >/dev/null
[ -d "$project" ] || die 'project registry removal deleted repository'
pass 'doctor core health, state permissions, and registry-only project removal'

printf 'workbench E2E passed: %s groups\n' "$pass_count"
