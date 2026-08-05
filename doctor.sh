#!/usr/bin/env bash
# doctor.sh — platform-aware aggregate environment check (read-only).
set -uo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
LOCK_FILE="$SETUP_DIR/locks/repos.lock"
WB_SETUP_DIR="$SETUP_DIR"
WB_MANIFEST="$MANIFEST"
# shellcheck source=lib/platform-selection.sh
source "$SETUP_DIR/lib/platform-selection.sh"

SHOW_SELECTION=0; PLATFORM_OVERRIDE=""; STRICT=0
WB_ONLY=(); WB_WITHOUT=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --show-selection) SHOW_SELECTION=1 ;;
    --strict) STRICT=1 ;;
    --platform)
      [ "$#" -ge 2 ] || { echo "--platform 값이 필요합니다" >&2; exit 2; }
      PLATFORM_OVERRIDE="$2"; shift ;;
    --without)
      [ "$#" -ge 2 ] || { echo "--without repo 이름이 필요합니다" >&2; exit 2; }
      WB_WITHOUT+=("$2"); shift ;;
    -h|--help)
      echo "usage: ./doctor.sh [--platform ID] [--without REPO] [--strict] [--show-selection] [REPO ...]"
      exit 0
      ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) WB_ONLY+=("$1") ;;
  esac
  shift
done

[ -f "$MANIFEST" ] || { echo "manifest 없음: $MANIFEST" >&2; exit 1; }
wb_prepare_selection "$PLATFORM_OVERRIDE" || exit $?
if [ "$SHOW_SELECTION" -eq 1 ]; then
  wb_show_selection
  exit $?
fi

expand(){ printf '%s' "${1/#\~/$HOME}"; }
G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[1;34m'; N='\033[0m'
fail=0

mark_problem() {
  local severity="$1"
  if [ "$severity" = "required" ] || [ "$STRICT" -eq 1 ]; then
    fail=1
  fi
}

printf '%b== platform ==%b\n' "$B" "$N"
printf "  %s\n\n" "$WB_PLATFORM_ID"
printf '%b== repo 상태 ==%b\n' "$B" "$N"
printf "%-13s %-10s %-6s %-10s %-7s %s\n" "repo" "severity" "git" "branch" "dirty" "배포링크"
while IFS='|' read -r name _url link _setup _sync || [ -n "$name" ]; do
  name="$(wb_trim "$name")"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  link="$(wb_trim "$link")"
  severity="$(wb_profile_severity "$name")"
  wb_decide_repo "$name" "$severity" || exit $?
  if [ "$WB_SELECTED" -ne 1 ]; then
    printf "%-13s %-10s %b\n" "$name" "$severity" "${Y}skipped ($WB_SELECTION_REASON)${N}"
    continue
  fi
  effective_severity="$WB_EFFECTIVE_SEVERITY"
  dir="$SETUP_DIR/$name"

  if [ -d "$dir/.git" ]; then
    br="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    dr="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    gitcol="${G}yes${N}"
  else
    br="-"; dr="-"; gitcol="${R}no${N}"
    mark_problem "$effective_severity"
  fi

  if [ -n "$link" ]; then
    tgt="$(expand "$link")"
    if [ -L "$tgt" ] && [ -e "$tgt" ]; then
      lk="${G}$link${N}"
    elif [ -e "$tgt" ]; then
      lk="${Y}$link (링크 아님)${N}"
      mark_problem "$effective_severity"
    else
      lk="${R}$link (없음/깨짐)${N}"
      mark_problem "$effective_severity"
    fi
  else
    lk="child-owned"
  fi
  printf "%-13s %-10s %-15b %-10s %-7s %b\n" "$name" "$effective_severity" "$gitcol" "$br" "$dr" "$lk"
done < "$MANIFEST"

printf '\n%b== compatible repo snapshot ==%b\n' "$B" "$N"
if [ ! -f "$LOCK_FILE" ]; then
  printf "  ${R}✗${N} lock 없음: %s\n" "$LOCK_FILE"
  fail=1
elif ! awk -F '|' '
  FNR == NR {
    name=$1
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
    if (name != "" && name !~ /^#/) manifest[name]=1
    next
  }
  FNR == 1 {
    if ($0 != "# schema-version: 1") {
      bad=1; print "  invalid schema header: " $0 > "/dev/stderr"
    }
    next
  }
  /^[[:space:]]*(#|$)/ {next}
  {
    count=split($0, fields, /[[:space:]]+/)
    name=fields[1]
    sha=fields[2]
    if (count != 2 || name !~ /^[A-Za-z0-9._-]+$/ || sha !~ /^[0-9a-f]{40}$/) {
      bad=1; print "  invalid row " FNR ": " $0 > "/dev/stderr"
    }
    if (!(name in manifest)) {bad=1; print "  unknown repo " name > "/dev/stderr"}
    if (seen[name]++) {bad=1; print "  duplicate repo " name > "/dev/stderr"}
  }
  END {
    for (name in manifest) if (!seen[name]) {bad=1; print "  missing repo " name > "/dev/stderr"}
    exit bad ? 1 : 0
  }
' "$MANIFEST" "$LOCK_FILE"; then
  printf '  %b✗%b lock 형식 오류\n' "$R" "$N"
  fail=1
else
  while read -r name expected; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    if [ ! -d "$SETUP_DIR/$name/.git" ]; then
      printf "  ${Y}!${N} %-13s checkout 없음\n" "$name"
      continue
    fi
    actual="$(git -C "$SETUP_DIR/$name" rev-parse HEAD 2>/dev/null)"
    if [ "$actual" = "$expected" ]; then
      printf "  ${G}✓${N} %-13s %s\n" "$name" "${actual:0:12}"
    else
      printf "  ${Y}!${N} %-13s current=%s expected=%s (report-only)\n" "$name" "${actual:0:12}" "${expected:0:12}"
    fi
  done < "$LOCK_FILE"
fi

printf '\n%b== 의존 계약: cmux → binbox (bb 명령) ==%b\n' "$B" "$N"
CMX="$SETUP_DIR/cmux-config"; BBX="$SETUP_DIR/binbox/libexec"
if [ -d "$CMX" ] && [ -d "$BBX" ]; then
  cmds=$(grep -rhoE '\bbb [a-z0-9_-]+' "$CMX/config.d" 2>/dev/null | awk '{print $2}' | sort -u)
  builtin_ok=" setup list help doctor check new upgrade "
  for c in $cmds; do
    if [ -f "$BBX/$c" ] || [ -f "$BBX/binbox-$c" ] || [[ "$builtin_ok" == *" $c "* ]]; then
      printf "  ${G}✓${N} bb %s\n" "$c"
    else
      printf "  ${R}✗${N} bb %s (binbox/libexec에 없음)\n" "$c"
      fail=1
    fi
  done
  [ -z "$cmds" ] && echo "  (참조 없음)"
else
  echo "  (cmux-config 또는 binbox 없음 — contract test에서 재확인)"
fi

printf "\n"
if [ "$fail" -eq 0 ]; then
  printf '%b환경 정상%b\n' "$G" "$N"
else
  printf '%b점검 필요 항목 있음 (위 표시)%b\n' "$Y" "$N"
fi
exit "$fail"
