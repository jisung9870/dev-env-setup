#!/usr/bin/env bash
# Shared platform/repository selection for bootstrap.sh, upgrade.sh, and doctor.sh.
# Bash 3.2 compatible: this file is sourced on macOS as well as Linux/WSL.

wb_trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

wb_contains() {
  local needle="$1" item
  shift
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

wb_manifest_names() {
  awk -F '|' '
    {
      name=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != "" && name !~ /^#/) print name
    }
  ' "$WB_MANIFEST"
}

wb_detect_platform() {
  if [ -n "${WSL_INTEROP:-}" ] || uname -r 2>/dev/null | grep -qi microsoft; then
    printf 'windows-wsl\n'
    return 0
  fi

  case "$(uname -s 2>/dev/null)" in
    Darwin) printf 'macos\n' ;;
    Linux) printf 'linux\n' ;;
    *)
      printf '지원하지 않는 platform입니다. --platform에 macos, linux, windows-wsl 중 하나를 지정하세요.\n' >&2
      return 2
      ;;
  esac
}

wb_validate_platform_file() {
  local profile_file="$1"
  awk -F '|' -v profile="$profile_file" '
    FNR == NR {
      name=$1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "" || name ~ /^#/) next
      if (manifest[name]++) {
        print "duplicate repo in manifest: " name > "/dev/stderr"
        bad=1
      }
      order[++manifest_count]=name
      next
    }
    FNR == 1 {
      if ($0 != "# schema-version: 1") {
        print profile ":1: expected # schema-version: 1" > "/dev/stderr"
        bad=1
      }
      next
    }
    {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^#/) next
      count=split(line, fields, /[[:space:]]+/)
      name=fields[1]
      severity=fields[2]
      if (count != 2) {
        print profile ":" FNR ": expected <repo> <severity>" > "/dev/stderr"
        bad=1
        next
      }
      if (!(name in manifest)) {
        print profile ":" FNR ": unknown repo: " name > "/dev/stderr"
        bad=1
      }
      if (seen[name]++) {
        print profile ":" FNR ": duplicate repo: " name > "/dev/stderr"
        bad=1
      }
      if (severity != "required" && severity != "optional" && severity != "disabled") {
        print profile ":" FNR ": invalid severity: " severity > "/dev/stderr"
        bad=1
      }
    }
    END {
      for (i=1; i<=manifest_count; i++) {
        name=order[i]
        if (!seen[name]) {
          print profile ": missing repo: " name > "/dev/stderr"
          bad=1
        }
      }
      exit bad ? 1 : 0
    }
  ' "$WB_MANIFEST" "$profile_file"
}

wb_validate_requested_repos() {
  local repo known
  for repo in "${WB_ONLY[@]}" "${WB_WITHOUT[@]}"; do
    [ -n "$repo" ] || continue
    known=0
    while IFS= read -r name; do
      [ "$name" = "$repo" ] && known=1
    done < <(wb_manifest_names)
    if [ "$known" -ne 1 ]; then
      printf 'manifest에 없는 repo: %s\n' "$repo" >&2
      return 2
    fi
  done

  for repo in "${WB_ONLY[@]}"; do
    if wb_contains "$repo" "${WB_WITHOUT[@]}"; then
      printf '같은 repo를 선택하고 제외할 수 없습니다: %s\n' "$repo" >&2
      return 2
    fi
  done
}

wb_prepare_selection() {
  local override="${1:-}"
  WB_PLATFORM_ID="${override:-${WB_PLATFORM:-}}"
  if [ -z "$WB_PLATFORM_ID" ]; then
    WB_PLATFORM_ID="$(wb_detect_platform)" || return $?
  fi

  case "$WB_PLATFORM_ID" in
    macos|linux|windows-wsl) ;;
    *)
      printf '지원하지 않는 platform: %s (macos, linux, windows-wsl)\n' "$WB_PLATFORM_ID" >&2
      return 2
      ;;
  esac

  WB_PLATFORM_FILE="$WB_SETUP_DIR/platforms/$WB_PLATFORM_ID.repos"
  [ -f "$WB_PLATFORM_FILE" ] || {
    printf 'platform profile 없음: %s\n' "$WB_PLATFORM_FILE" >&2
    return 1
  }
  wb_validate_platform_file "$WB_PLATFORM_FILE" || return $?
  wb_validate_requested_repos || return $?
}

# Sets WB_SELECTED, WB_EFFECTIVE_SEVERITY, and WB_SELECTION_REASON.
wb_decide_repo() {
  local name="$1" profile_severity="$2"
  WB_SELECTED=0
  WB_EFFECTIVE_SEVERITY="$profile_severity"
  WB_SELECTION_REASON="profile"

  if [ "${#WB_ONLY[@]}" -gt 0 ]; then
    if wb_contains "$name" "${WB_ONLY[@]}"; then
      WB_SELECTED=1
      WB_EFFECTIVE_SEVERITY="required"
      WB_SELECTION_REASON="explicit"
    else
      WB_SELECTION_REASON="not-requested"
    fi
    return 0
  fi

  if wb_contains "$name" "${WB_WITHOUT[@]}"; then
    if [ "$profile_severity" != "optional" ]; then
      printf '%s repo는 %s이므로 --without으로 제외할 수 없습니다.\n' "$name" "$profile_severity" >&2
      return 2
    fi
    WB_SELECTION_REASON="excluded"
    return 0
  fi

  if [ "$profile_severity" = "disabled" ]; then
    WB_SELECTION_REASON="disabled"
    return 0
  fi
  WB_SELECTED=1
}

wb_show_selection() {
  local name severity
  printf 'platform %s\n' "$WB_PLATFORM_ID"
  while read -r name severity; do
    [ -n "$name" ] || continue
    wb_decide_repo "$name" "$severity" || return $?
    if [ "$WB_SELECTED" -eq 1 ]; then
      printf 'repo %s %s selected %s %s\n' "$name" "$severity" "$WB_EFFECTIVE_SEVERITY" "$WB_SELECTION_REASON"
    else
      printf 'repo %s %s skipped %s %s\n' "$name" "$severity" "$WB_EFFECTIVE_SEVERITY" "$WB_SELECTION_REASON"
    fi
  done < <(awk '!/^[[:space:]]*(#|$)/ {print $1, $2}' "$WB_PLATFORM_FILE")
}

wb_profile_severity() {
  local wanted="$1"
  awk -v wanted="$wanted" '$1 == wanted {print $2; exit}' "$WB_PLATFORM_FILE"
}
