#!/usr/bin/env bash

wb_lock_validate() {
  local setup_root="$1" lock_file="$1/locks/repos.lock" manifest="$1/repos.txt"
  local manifest_names="" lock_names="" line_number=0 name sha extra row
  [ -f "$manifest" ] || { printf 'lock error: missing %s\n' "$manifest" >&2; return 2; }
  [ -f "$lock_file" ] || { printf 'lock error: missing %s\n' "$lock_file" >&2; return 2; }
  while IFS='|' read -r name row || [ -n "$name" ]; do
    name="$(printf '%s' "$name" | xargs)"
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    manifest_names="${manifest_names}${manifest_names:+$'\n'}$name"
  done <"$manifest"
  while IFS= read -r row || [ -n "$row" ]; do
    line_number=$((line_number + 1))
    row="$(printf '%s' "$row" | xargs)"
    [ -z "$row" ] && continue
    case "$row" in \#*) continue ;; esac
    IFS=' ' read -r name sha extra <<<"$row"
    if [ -z "$name" ] || [ -z "$sha" ] || [ -n "$extra" ] || ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
      printf 'lock error: %s:%s expected: <repo> <40-char-lowercase-sha>\n' "$lock_file" "$line_number" >&2
      return 2
    fi
    printf '%s\n' "$manifest_names" | grep -Fxq "$name" || { printf "lock error: %s:%s unknown repo '%s'\n" "$lock_file" "$line_number" "$name" >&2; return 2; }
    printf '%s\n' "$lock_names" | grep -Fxq "$name" && { printf "lock error: %s:%s duplicate repo '%s'\n" "$lock_file" "$line_number" "$name" >&2; return 2; }
    lock_names="${lock_names}${lock_names:+$'\n'}$name"
  done <"$lock_file"
  while IFS= read -r name; do
    printf '%s\n' "$lock_names" | grep -Fxq "$name" || { printf "lock error: %s missing manifest repo '%s'\n" "$lock_file" "$name" >&2; return 2; }
  done <<<"$manifest_names"
}

wb_lock_report() {
  local setup_root="$1" lock_file="$1/locks/repos.lock" name expected actual state
  wb_lock_validate "$setup_root" || return 2
  while read -r name expected; do
    [ -z "$name" ] && continue
    case "$name" in \#*) continue ;; esac
    if [ ! -d "$setup_root/$name/.git" ]; then
      printf 'snapshot|%s|missing|%s|-\n' "$name" "$expected"
      continue
    fi
    actual="$(git -C "$setup_root/$name" rev-parse HEAD 2>/dev/null || true)"
    state="match"; [ "$actual" = "$expected" ] || state="mismatch"
    printf 'snapshot|%s|%s|%s|%s\n' "$name" "$state" "$expected" "$actual"
  done <"$lock_file"
}
