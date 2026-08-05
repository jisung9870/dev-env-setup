#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_base="${TMPDIR:-/tmp}"
tmp_root="$(mktemp -d "${tmp_base%/}/workbench-json.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/config/tmux-sessionizer" "$tmp_root/projects/alpha project" \
  "$tmp_root/projects/quote\"project" "$tmp_root/direct"
printf '%s\n=%s\n' "$tmp_root/projects" "$tmp_root/direct" >"$tmp_root/config/tmux-sessionizer/dirs"

XDG_CONFIG_HOME="$tmp_root/config" "$repo_root/binbox/bb" tm projects --json >"$tmp_root/projects.json"
"$repo_root/binbox/bb" tm sessions --json >"$tmp_root/sessions.json"
"$repo_root/binbox/bb" agents --json >"$tmp_root/agents.json"

set +e
"$repo_root/binbox/bb" doctor --json >"$tmp_root/doctor.json"
doctor_status=$?
set -e
[ "$doctor_status" -eq 0 ] || [ "$doctor_status" -eq 1 ]

mkdir -p "$tmp_root/minimal-path"
for command_name in bash dirname readlink uname python3; do
  command_path="$(command -v "$command_name")"
  if [ "$command_name" = "python3" ] && command -v asdf >/dev/null 2>&1; then
    command_path="$(asdf which python3)"
  fi
  ln -s "$command_path" "$tmp_root/minimal-path/$command_name"
done
set +e
PATH="$tmp_root/minimal-path" "$repo_root/binbox/libexec/tm" sessions --json >"$tmp_root/sessions-unavailable.json"
sessions_unavailable_status=$?
PATH="$tmp_root/minimal-path" "$repo_root/binbox/libexec/agents" --json >"$tmp_root/agents-unavailable.json"
agents_unavailable_status=$?
PATH="$tmp_root/minimal-path" "$repo_root/binbox/libexec/binbox-doctor" --json >"$tmp_root/doctor-missing-core.json"
doctor_missing_status=$?
set -e
[ "$sessions_unavailable_status" -eq 3 ]
[ "$agents_unavailable_status" -eq 3 ]
[ "$doctor_missing_status" -eq 1 ]

set +e
"$repo_root/binbox/bb" agents --json extra >"$tmp_root/invalid-argument.json"
invalid_argument_status=$?
set -e
[ "$invalid_argument_status" -eq 2 ]

python3 - "$tmp_root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

def load(name, collection):
    payload = json.loads((root / f"{name}.json").read_text())
    assert payload["schema_version"] == 1
    assert isinstance(payload["ok"], bool)
    assert isinstance(payload["warnings"], list)
    assert "error" in payload
    assert isinstance(payload["data"][collection], list)
    return payload

projects = load("projects", "projects")
paths = sorted(item["path"] for item in projects["data"]["projects"])
assert paths == sorted([
    str(root / "direct"),
    str(root / "projects" / "alpha project"),
    str(root / "projects" / 'quote"project'),
])
load("sessions", "sessions")
load("agents", "agents")
load("doctor", "capabilities")
for name in ("sessions-unavailable", "agents-unavailable"):
    payload = json.loads((root / f"{name}.json").read_text())
    assert payload["schema_version"] == 1
    assert payload["ok"] is False
    assert payload["error"]["code"] == "CAPABILITY_UNAVAILABLE"
doctor_missing = json.loads((root / "doctor-missing-core.json").read_text())
assert doctor_missing["ok"] is False
assert doctor_missing["error"]["code"] == "CORE_DEPENDENCY_MISSING"
invalid = json.loads((root / "invalid-argument.json").read_text())
assert invalid["ok"] is False
assert invalid["error"]["code"] == "INVALID_ARGUMENT"
PY

PATH="$repo_root/binbox:$PATH" XDG_CONFIG_HOME="$tmp_root/config" NVIM_LOG_FILE=/dev/null \
  nvim --headless -u NONE -l "$repo_root/nvim/scripts/workbench-client-smoke.lua"

printf 'json contracts: ok\n'
