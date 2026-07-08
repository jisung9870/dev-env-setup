#!/usr/bin/env bash
#
# doctor.sh — 개인 환경 상태 점검 (읽기 전용, 아무것도 바꾸지 않음)
#
#   각 repo: 존재 / git / 브랜치 / 로컬변경 / 배포 링크 해석
#   의존 계약: cmux 가 부르는 `bb <tool>` 이 binbox/libexec 에 있는지 대조
#
set -uo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
expand(){ printf '%s' "${1/#\~/$HOME}"; }

G='\033[32m'; Y='\033[33m'; R='\033[31m'; B='\033[1;34m'; N='\033[0m'
fail=0

printf "${B}== repo 상태 ==${N}\n"
printf "%-13s %-6s %-10s %-7s %s\n" "repo" "git" "branch" "dirty" "배포링크"
while IFS='|' read -r name url link setup sync || [ -n "$name" ]; do
  name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  link="$(echo "$link" | xargs)"
  dir="$SETUP_DIR/$name"

  if [ -d "$dir/.git" ]; then
    br="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    dr="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    gitcol="${G}yes${N}"
  else
    br="-"; dr="-"; gitcol="${R}no${N}"; fail=1
  fi

  if [ -n "$link" ]; then
    tgt="$(expand "$link")"
    if [ -L "$tgt" ] && [ -e "$tgt" ]; then lk="${G}$link${N}";
    elif [ -e "$tgt" ]; then lk="${Y}$link (링크 아님)${N}";
    else lk="${R}$link (없음/깨짐)${N}"; fail=1; fi
  else
    lk="-"
  fi
  printf "%-13s %-15b %-10s %-7s %b\n" "$name" "$gitcol" "$br" "$dr" "$lk"
done < "$MANIFEST"

printf "\n${B}== 의존 계약: cmux → binbox (bb 명령) ==${N}\n"
CMX="$SETUP_DIR/cmux-config"; BBX="$SETUP_DIR/binbox/libexec"
if [ -d "$CMX" ] && [ -d "$BBX" ]; then
  # cmux config 에서 참조하는 `bb <tool>` 토큰 추출
  cmds=$(grep -rhoE '\bbb [a-z0-9_-]+' "$CMX" 2>/dev/null | awk '{print $2}' | sort -u)
  builtin_ok=" setup list help doctor check new upgrade "   # bb 내장/특수 명령
  for c in $cmds; do
    if [ -f "$BBX/$c" ] || [ -f "$BBX/binbox-$c" ] || [[ "$builtin_ok" == *" $c "* ]]; then
      printf "  ${G}✓${N} bb %s\n" "$c"
    else
      printf "  ${R}✗${N} bb %s  (binbox/libexec 에 없음 — 계약 깨짐 가능)\n" "$c"; fail=1
    fi
  done
  [ -z "$cmds" ] && echo "  (참조 없음)"
else
  echo "  (cmux-config 또는 binbox 없음 — 건너뜀)"
fi

printf "\n"
if [ "$fail" -eq 0 ]; then printf "${G}환경 정상${N}\n"; else printf "${Y}점검 필요 항목 있음 (위 표시) → ./bootstrap.sh 로 복구${N}\n"; fi
exit $fail
