#!/usr/bin/env bash

# Shared, read-only repository selection for bootstrap.sh, upgrade.sh, and doctor.sh.
# Call wb_selector_init, add caller options, then wb_selector_resolve <setup-root>.

wb_selector_init() {
  WB_SELECTOR_PLATFORM_OPTION=""
  WB_SELECTOR_PLATFORM=""
  WB_SELECTOR_POSITIONAL=()
  WB_SELECTOR_WITH=()
  WB_SELECTOR_WITHOUT=()
  WB_SELECTOR_MANIFEST_NAMES=""
  WB_SELECTOR_PROFILE_ROWS=""
  WB_SELECTOR_RECORDS=""
}

wb_selector_error() {
  printf 'selection error: %s\n' "$*" >&2
  return 2
}

wb_selector_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

wb_selector_list_contains() {
  local list="$1" expected="$2" item
  while IFS= read -r item; do
    [ "$item" = "$expected" ] && return 0
  done <<<"$list"
  return 1
}

wb_selector_array_contains() {
  local expected="$1" item
  shift
  for item in "$@"; do
    [ "$item" = "$expected" ] && return 0
  done
  return 1
}

wb_selector_add_unique() {
  local kind="$1" value="$2"
  case "$kind" in
    positional)
      wb_selector_array_contains "$value" ${WB_SELECTOR_POSITIONAL[@]+"${WB_SELECTOR_POSITIONAL[@]}"} || WB_SELECTOR_POSITIONAL+=("$value")
      ;;
    with)
      wb_selector_array_contains "$value" ${WB_SELECTOR_WITH[@]+"${WB_SELECTOR_WITH[@]}"} || WB_SELECTOR_WITH+=("$value")
      ;;
    without)
      wb_selector_array_contains "$value" ${WB_SELECTOR_WITHOUT[@]+"${WB_SELECTOR_WITHOUT[@]}"} || WB_SELECTOR_WITHOUT+=("$value")
      ;;
    *) wb_selector_error "internal unknown list: $kind" ;;
  esac
}

wb_selector_detect_platform() {
  local uname_s="${1:-}" uname_r="${2:-}" wsl_interop="${3:-${WSL_INTEROP:-}}"
  [ -n "$uname_s" ] || uname_s="$(uname -s 2>/dev/null || true)"
  [ -n "$uname_r" ] || uname_r="$(uname -r 2>/dev/null || true)"
  if [ -n "$wsl_interop" ] || printf '%s' "$uname_r" | grep -qi microsoft; then
    printf 'windows-wsl\n'
  elif [ "$uname_s" = "Darwin" ]; then
    printf 'macos\n'
  elif [ "$uname_s" = "Linux" ]; then
    printf 'linux\n'
  else
    wb_selector_error "unsupported platform '$uname_s' (supported: macos, linux, windows-wsl)"
  fi
}

wb_selector_declared_severity() {
  local expected="$1" name severity
  while IFS='|' read -r name severity; do
    [ "$name" = "$expected" ] && { printf '%s\n' "$severity"; return 0; }
  done <<<"$WB_SELECTOR_PROFILE_ROWS"
  return 1
}

wb_selector_validate_input_names() {
  local kind item
  for kind in positional with without; do
    case "$kind" in
      positional) set -- ${WB_SELECTOR_POSITIONAL[@]+"${WB_SELECTOR_POSITIONAL[@]}"} ;;
      with) set -- ${WB_SELECTOR_WITH[@]+"${WB_SELECTOR_WITH[@]}"} ;;
      without) set -- ${WB_SELECTOR_WITHOUT[@]+"${WB_SELECTOR_WITHOUT[@]}"} ;;
    esac
    for item in "$@"; do
      wb_selector_list_contains "$WB_SELECTOR_MANIFEST_NAMES" "$item" || {
        wb_selector_error "unknown repo '$item' in --$kind selection"
        return 2
      }
    done
  done
  for item in ${WB_SELECTOR_WITHOUT[@]+"${WB_SELECTOR_WITHOUT[@]}"}; do
    if wb_selector_array_contains "$item" ${WB_SELECTOR_POSITIONAL[@]+"${WB_SELECTOR_POSITIONAL[@]}"} || wb_selector_array_contains "$item" ${WB_SELECTOR_WITH[@]+"${WB_SELECTOR_WITH[@]}"}; then
      wb_selector_error "repo '$item' cannot be both included and excluded"
      return 2
    fi
    if [ "$(wb_selector_declared_severity "$item")" = "required" ]; then
      wb_selector_error "required repo '$item' cannot be excluded"
      return 2
    fi
  done
}

wb_selector_resolve() {
  local setup_root="$1" manifest="$1/repos.txt" platform_file
  local line_number=0 line name url _link _setup _sync severity extra manifest_count=0 profile_count=0
  [ -f "$manifest" ] || { wb_selector_error "manifest missing: $manifest"; return 2; }

  if [ -n "$WB_SELECTOR_PLATFORM_OPTION" ]; then
    WB_SELECTOR_PLATFORM="$WB_SELECTOR_PLATFORM_OPTION"
  elif [ -n "${WB_PLATFORM:-}" ]; then
    WB_SELECTOR_PLATFORM="$WB_PLATFORM"
  else
    WB_SELECTOR_PLATFORM="$(wb_selector_detect_platform)" || return 2
  fi
  case "$WB_SELECTOR_PLATFORM" in
    macos|linux|windows-wsl) ;;
    *) wb_selector_error "unsupported platform '$WB_SELECTOR_PLATFORM' (supported: macos, linux, windows-wsl)"; return 2 ;;
  esac

  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    line="$(wb_selector_trim "$line")"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    extra="${line//[^|]/}"
    if [ "${#extra}" -ne 4 ]; then
      wb_selector_error "$manifest:$line_number expected exactly five pipe-delimited fields"
      return 2
    fi
    IFS='|' read -r name url _link _setup _sync <<<"$line"
    name="$(wb_selector_trim "$name")"
    url="$(wb_selector_trim "$url")"
    if [ -z "$name" ] || [ -z "$url" ]; then
      wb_selector_error "$manifest:$line_number repository name and URL are required"
      return 2
    fi
    if wb_selector_list_contains "$WB_SELECTOR_MANIFEST_NAMES" "$name"; then
      wb_selector_error "$manifest:$line_number duplicate repo '$name'"
      return 2
    fi
    WB_SELECTOR_MANIFEST_NAMES="${WB_SELECTOR_MANIFEST_NAMES}${WB_SELECTOR_MANIFEST_NAMES:+$'\n'}$name"
    manifest_count=$((manifest_count + 1))
  done <"$manifest"
  [ "$manifest_count" -gt 0 ] || { wb_selector_error "$manifest contains no repositories"; return 2; }

  platform_file="$setup_root/platforms/$WB_SELECTOR_PLATFORM.repos"
  [ -f "$platform_file" ] || { wb_selector_error "platform profile missing: $platform_file"; return 2; }
  line_number=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    line="$(wb_selector_trim "$line")"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    IFS=' ' read -r name severity extra <<<"$line"
    if [ -z "$name" ] || [ -z "$severity" ] || [ -n "$extra" ]; then
      wb_selector_error "$platform_file:$line_number expected: <repo> <required|optional|disabled>"
      return 2
    fi
    case "$severity" in required|optional|disabled) ;; *) wb_selector_error "$platform_file:$line_number invalid severity '$severity'"; return 2 ;; esac
    wb_selector_list_contains "$WB_SELECTOR_MANIFEST_NAMES" "$name" || {
      wb_selector_error "$platform_file:$line_number repo '$name' is not in repos.txt"
      return 2
    }
    if wb_selector_declared_severity "$name" >/dev/null 2>&1; then
      wb_selector_error "$platform_file:$line_number duplicate repo '$name'"
      return 2
    fi
    WB_SELECTOR_PROFILE_ROWS="${WB_SELECTOR_PROFILE_ROWS}${WB_SELECTOR_PROFILE_ROWS:+$'\n'}$name|$severity"
    profile_count=$((profile_count + 1))
  done <"$platform_file"
  if [ "$profile_count" -ne "$manifest_count" ]; then
    wb_selector_error "$platform_file must contain every manifest repo exactly once"
    return 2
  fi
  while IFS= read -r name; do
    wb_selector_declared_severity "$name" >/dev/null 2>&1 || {
      wb_selector_error "$platform_file missing manifest repo '$name'"
      return 2
    }
  done <<<"$WB_SELECTOR_MANIFEST_NAMES"

  wb_selector_validate_input_names || return 2

  local selected effective reason
  while IFS= read -r name; do
    severity="$(wb_selector_declared_severity "$name")"
    selected="selected"; effective="$severity"; reason="platform-default"
    if [ "$severity" = "disabled" ]; then
      selected="skipped"; reason="platform-disabled"
    fi
    if [ -n "${WB_SELECTOR_POSITIONAL[*]-}" ]; then
      selected="skipped"; reason="positional-subset"
      if wb_selector_array_contains "$name" ${WB_SELECTOR_POSITIONAL[@]+"${WB_SELECTOR_POSITIONAL[@]}"}; then
        selected="selected"; effective="required"; reason="positional"
      fi
    fi
    if wb_selector_array_contains "$name" ${WB_SELECTOR_WITH[@]+"${WB_SELECTOR_WITH[@]}"}; then
      selected="selected"; effective="required"; reason="with"
    fi
    if wb_selector_array_contains "$name" ${WB_SELECTOR_WITHOUT[@]+"${WB_SELECTOR_WITHOUT[@]}"}; then
      selected="skipped"; effective="$severity"; reason="without"
    fi
    WB_SELECTOR_RECORDS="${WB_SELECTOR_RECORDS}${WB_SELECTOR_RECORDS:+$'\n'}$name|$severity|$selected|$effective|$reason"
  done <<<"$WB_SELECTOR_MANIFEST_NAMES"
}

wb_selector_show() {
  local name severity selected effective reason
  printf 'platform|%s\n' "$WB_SELECTOR_PLATFORM"
  while IFS='|' read -r name severity selected effective reason; do
    printf 'repo|%s|%s|%s|%s|%s\n' "$name" "$severity" "$selected" "$effective" "$reason"
  done <<<"$WB_SELECTOR_RECORDS"
}

wb_selector_record() {
  local expected="$1" name severity selected effective reason
  while IFS='|' read -r name severity selected effective reason; do
    [ "$name" = "$expected" ] && { printf '%s|%s|%s|%s|%s\n' "$name" "$severity" "$selected" "$effective" "$reason"; return 0; }
  done <<<"$WB_SELECTOR_RECORDS"
  return 1
}

wb_selector_selected() {
  local record
  record="$(wb_selector_record "$1")" || return 1
  [ "$(printf '%s' "$record" | cut -d'|' -f3)" = "selected" ]
}

wb_selector_effective_severity() {
  local record
  record="$(wb_selector_record "$1")" || return 1
  printf '%s\n' "$(printf '%s' "$record" | cut -d'|' -f4)"
}
