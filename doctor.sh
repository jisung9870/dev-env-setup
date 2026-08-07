#!/usr/bin/env bash
#
# doctor.sh — read-only aggregate environment health check
#
# Usage:
#   ./doctor.sh [--platform <id>] [--with <repo>] [--without <repo>] [repo ...]
#   ./doctor.sh --show-selection [selection options]
#
set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
# shellcheck source=lib/repo-selector.sh
source "$SETUP_DIR/lib/repo-selector.sh"
# shellcheck source=lib/repo-lock.sh
source "$SETUP_DIR/lib/repo-lock.sh"
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

wb_selector_resolve "$SETUP_DIR" || exit 2
if [ "$SHOW_SELECTION" -eq 1 ]; then
  wb_selector_show
  exit 0
fi

expand() { printf '%s' "${1/#\~/$HOME}"; }
G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[1;34m'; N='\033[0m'
fail=0

mark_issue() {
  local name="$1" message="$2" severity
  severity="$(wb_selector_effective_severity "$name")"
  if [ "$severity" = "required" ]; then
    printf '  %b✗%b %s\n' "$R" "$N" "$message"
    fail=1
  else
    printf '  %b!%b %s\n' "$Y" "$N" "$message"
  fi
}

printf "%b== repository state (%s) ==%b\n" "$B" "$WB_SELECTOR_PLATFORM" "$N"
printf '%-13s %-9s %-10s %-7s %-9s %s\n' repo severity branch dirty selection link
while IFS='|' read -r name _url link _setup _sync || [ -n "$name" ]; do
  name="$(wb_selector_trim "$name")"
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  severity="$(wb_selector_effective_severity "$name")"
  if ! wb_selector_selected "$name"; then
    printf '%-13s %-9s %-10s %-7s %-9s %s\n' "$name" "$severity" - - skipped -
    continue
  fi
  link="$(wb_selector_trim "$link")"
  dir="$SETUP_DIR/$name"
  if [ -d "$dir/.git" ]; then
    if branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" && status_output="$(git -C "$dir" status --porcelain 2>/dev/null)"; then
      if [ -n "$status_output" ]; then
        dirty="$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')"
      else
        dirty=0
      fi
      repo_state=yes
    else
      branch='?'; dirty='?'; repo_state=invalid
      mark_issue "$name" "$name checkout is not a readable Git repository"
    fi
  else
    branch=-; dirty=-; repo_state=no
    mark_issue "$name" "$name repository is missing"
  fi
  link_state=-
  if [ -n "$link" ]; then
    target="$(expand "$link")"
    if [ -L "$target" ] && [ -e "$target" ]; then
      link_state="$link"
    elif [ -e "$target" ]; then
      link_state="$link (not-link)"
      mark_issue "$name" "$link exists but is not a symlink"
    else
      link_state="$link (missing)"
      mark_issue "$name" "$link is missing or broken"
    fi
  fi
  printf '%-13s %-9s %-10s %-7s %-9s %s\n' "$name" "$severity" "$branch" "$dirty" "$repo_state" "$link_state"
done <"$MANIFEST"

printf '\n%b== compatible repository snapshot (report-only) ==%b\n' "$B" "$N"
if snapshot_output="$(wb_lock_report "$SETUP_DIR")"; then
  printf '%s\n' "$snapshot_output"
  if printf '%s\n' "$snapshot_output" | grep -Eq '^snapshot\|[^|]+\|(mismatch|missing)\|'; then
    printf '  %b!%b snapshot differs from the compatible baseline; no checkout was changed\n' "$Y" "$N"
  fi
else
  printf '  %b✗%b repository lock schema is invalid\n' "$R" "$N"
  fail=1
fi

printf '\n%b== dependency contract: cmux → binbox ==%b\n' "$B" "$N"
if wb_selector_selected cmux-config; then
  CMX="$SETUP_DIR/cmux-config"
  BBX="$SETUP_DIR/binbox/libexec"
  if [ -d "$CMX" ] && [ -d "$BBX" ]; then
    commands="$(grep -rhoE '\bbb [a-z0-9_-]+' "$CMX" 2>/dev/null | awk '{print $2}' | sort -u)"
    builtin_ok=' setup list help doctor check new upgrade '
    for command_name in $commands; do
      if [ -f "$BBX/$command_name" ] || [ -f "$BBX/binbox-$command_name" ] || [[ "$builtin_ok" == *" $command_name "* ]]; then
        printf '  %b✓%b bb %s\n' "$G" "$N" "$command_name"
      else
        mark_issue cmux-config "bb $command_name is referenced but absent from binbox/libexec"
      fi
    done
    [ -n "$commands" ] || printf '  (no bb references)\n'
  else
    mark_issue cmux-config 'cmux-config or binbox/libexec is unavailable'
  fi
else
  printf '  skipped by platform selection\n'
fi

printf '\n%b== Workbench CLI ==%b\n' "$B" "$N"
if wb_selector_selected workbench; then
  wb_managed="$HOME/.local/bin/wb"
  wb_path="$(command -v wb 2>/dev/null || true)"
  [ -n "$wb_path" ] || [ ! -x "$wb_managed" ] || wb_path="$wb_managed"
  if [ -x "$wb_path" ]; then
    printf '  %b✓%b %s\n' "$G" "$N" "$wb_path"
    # 'make install' owns $wb_managed. If PATH resolves wb to a different file,
    # the managed build is shadowed and later installs silently go unused.
    if [ ! -x "$wb_managed" ]; then
      mark_issue workbench "wb resolves to $wb_path but the managed install $wb_managed is missing; run: make -C workbench install"
    elif ! [ "$wb_path" -ef "$wb_managed" ]; then
      mark_issue workbench "wb resolves to $wb_path and shadows the managed install $wb_managed; remove the shadowing copy or fix PATH order"
    fi
  else
    mark_issue workbench 'wb is not installed; install Go 1.25.12, then run: make -C workbench install'
  fi
else
  printf '  skipped by platform selection\n'
fi

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf '%benvironment healthy%b\n' "$G" "$N"
else
  printf '%brequired health checks failed; inspect above%b\n' "$Y" "$N"
fi
exit "$fail"
