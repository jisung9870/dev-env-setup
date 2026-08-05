#!/usr/bin/env bash
#
# upgrade.sh — synchronize managed repositories in dependency order
#
# Usage:
#   ./upgrade.sh [--platform <id>] [--with <repo>] [--without <repo>] [repo ...]
#   ./upgrade.sh --show-selection [selection options]
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
# shellcheck source=lib/repo-selector.sh
source "$SETUP_DIR/lib/repo-selector.sh"
wb_selector_init
SHOW_SELECTION=0

require_value() {
  [ "$#" -ge 2 ] && [ -n "$2" ] || { printf 'option requires a value: %s\n' "$1" >&2; exit 2; }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform) require_value "$@"; WB_SELECTOR_PLATFORM_OPTION="$2"; shift 2 ;;
    --with) require_value "$@"; wb_selector_add_unique with "$2"; shift 2 ;;
    --without) require_value "$@"; wb_selector_add_unique without "$2"; shift 2 ;;
    --show-selection) SHOW_SELECTION=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) wb_selector_add_unique positional "$1"; shift ;;
  esac
done

wb_selector_resolve "$SETUP_DIR"
if [ "$SHOW_SELECTION" -eq 1 ]; then
  wb_selector_show
  exit 0
fi

info() { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

fail=0
mark_failure() {
  local name="$1" message="$2" severity
  severity="$(wb_selector_effective_severity "$name")"
  warn "$message"
  [ "$severity" = "required" ] && fail=1
  return 0
}

workbench_toolchain_ready() {
  local dir="$1" version
  version="$(cd "$dir" && go version 2>/dev/null)" || return 1
  case "$version" in
    'go version go1.25.12 '*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS='|' read -r name _url _link _setup sync || [ -n "$name" ]; do
  name="$(wb_selector_trim "$name")"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  wb_selector_selected "$name" || continue
  sync="$(wb_selector_trim "$sync")"
  [ -z "$sync" ] && continue

  info "$name"
  dir="$SETUP_DIR/$name"
  if [ ! -d "$dir/.git" ]; then
    mark_failure "$name" "repo missing; run ./bootstrap.sh first"
    continue
  fi
  if [ "$name" = "workbench" ] && ! workbench_toolchain_ready "$dir"; then
    mark_failure "$name" 'Go 1.25.12 is required; install it first (asdf: asdf install golang 1.25.12)'
    continue
  fi
  if (cd "$dir" && eval "$sync"); then
    ok "sync: $sync"
  else
    mark_failure "$name" "sync failed: $sync"
  fi
done <"$MANIFEST"

if [ "$fail" -eq 0 ]; then
  info "complete. Inspect state with: ./doctor.sh"
else
  warn "synchronization completed with required failures; inspect above and run ./doctor.sh"
fi
exit "$fail"
