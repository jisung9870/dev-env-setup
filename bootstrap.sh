#!/usr/bin/env bash
#
# bootstrap.sh — cross-platform personal environment provisioning (idempotent)
#
# Usage:
#   ./bootstrap.sh [--platform <id>] [--with <repo>] [--without <repo>]
#                  [--no-pull] [--no-setup] [--link-only] [repo ...]
#   ./bootstrap.sh --show-selection [selection options]
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
# shellcheck source=lib/repo-selector.sh
source "$SETUP_DIR/lib/repo-selector.sh"
wb_selector_init

NO_PULL=0
NO_SETUP=0
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
    --no-pull) NO_PULL=1; shift ;;
    --no-setup) NO_SETUP=1; shift ;;
    --link-only) NO_PULL=1; NO_SETUP=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
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
expand() { printf '%s' "${1/#\~/$HOME}"; }

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

while IFS='|' read -r name url link setup _sync || [ -n "$name" ]; do
  name="$(wb_selector_trim "$name")"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  wb_selector_selected "$name" || continue
  url="$(wb_selector_trim "$url")"
  link="$(wb_selector_trim "$link")"
  setup="$(wb_selector_trim "$setup")"

  info "$name"
  dir="$SETUP_DIR/$name"

  if [ ! -d "$dir/.git" ]; then
    if [ -z "$url" ]; then
      mark_failure "$name" "repo missing and URL is empty"
      continue
    fi
    if git clone "$url" "$dir"; then
      ok "cloned $url"
    else
      mark_failure "$name" "clone failed: $url"
      continue
    fi
  elif [ "$NO_PULL" -eq 0 ]; then
    if [ -z "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
      if git -C "$dir" pull --ff-only >/dev/null 2>&1; then
        ok "pulled (ff)"
      else
        mark_failure "$name" "pull failed (not fast-forward or offline); existing checkout preserved"
      fi
    else
      warn "tracked local changes present; pull skipped"
    fi
  fi

  if [ -n "$link" ]; then
    target="$(expand "$link")"
    if mkdir -p "$(dirname "$target")" && ln -sfn "$dir" "$target" && [ -e "$target" ]; then
      ok "link $link → $name"
    else
      mark_failure "$name" "link failed: $link"
    fi
  fi

  if [ -n "$setup" ] && [ "$NO_SETUP" -eq 0 ]; then
    if [ "$name" = "workbench" ] && ! workbench_toolchain_ready "$dir"; then
      mark_failure "$name" 'Go 1.25.12 is required; install it first (asdf: asdf install golang 1.25.12)'
      continue
    fi
    if (cd "$dir" && eval "$setup"); then
      ok "setup: $setup"
    else
      mark_failure "$name" "setup failed: $setup"
    fi
  fi
done <"$MANIFEST"

if [ "$fail" -eq 0 ]; then
  info "complete. Inspect state with: ./doctor.sh"
else
  warn "provisioning completed with required failures; inspect above and run ./doctor.sh"
fi
exit "$fail"
