#!/usr/bin/env bash
#
# upgrade.sh — 개인 환경 repo 를 "최신으로 동기화" (쓰기)
#
# repos.txt 매니페스트의 sync_cmd 컬럼을 의존 순서대로 실행:
#   binbox  → ./bb upgrade                          (git pull + changelog)
#   nvim    → ./scripts/setup.sh --sync --sync-plugins (git pull + Lazy 복원)
#   cmux    → git pull --ff-only                     (라이브는 링크라 pull 하면 반영)
#
# bootstrap.sh 가 "프로비저닝(clone/link/setup)" 이라면, 이건 "최신 반영" 전용이다.
# cmux 라이브 변경을 repo 로 캡처하려면 별도로 cmux-config/scripts/pull-local.sh (역방향).
#
# 사용법:
#   ./upgrade.sh                  # 전체 최신 동기화
#   ./upgrade.sh binbox nvim      # 특정 repo만
#   ./upgrade.sh --show-selection
#   ./upgrade.sh --platform windows-wsl
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
WB_SETUP_DIR="$SETUP_DIR"
WB_MANIFEST="$MANIFEST"
# shellcheck source=lib/platform-selection.sh
source "$SETUP_DIR/lib/platform-selection.sh"

SHOW_SELECTION=0; PLATFORM_OVERRIDE=""
WB_ONLY=(); WB_WITHOUT=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --show-selection) SHOW_SELECTION=1 ;;
    --platform)
      [ "$#" -ge 2 ] || { echo "--platform 값이 필요합니다" >&2; exit 2; }
      PLATFORM_OVERRIDE="$2"; shift ;;
    --without)
      [ "$#" -ge 2 ] || { echo "--without repo 이름이 필요합니다" >&2; exit 2; }
      WB_WITHOUT+=("$2"); shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*)        echo "unknown option: $1" >&2; exit 2 ;;
    *)         WB_ONLY+=("$1") ;;
  esac
  shift
done

info(){ printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

[ -f "$MANIFEST" ] || { echo "manifest 없음: $MANIFEST" >&2; exit 1; }
wb_prepare_selection "$PLATFORM_OVERRIDE"
if [ "$SHOW_SELECTION" -eq 1 ]; then
  wb_show_selection
  exit $?
fi

aggregate_fail=0
info "platform: $WB_PLATFORM_ID"

while IFS='|' read -r name _url _link _setup sync || [ -n "$name" ]; do
  name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  sync="$(echo "$sync" | xargs)"
  severity="$(wb_profile_severity "$name")"
  wb_decide_repo "$name" "$severity"
  [ "$WB_SELECTED" -eq 1 ] || continue
  effective_severity="$WB_EFFECTIVE_SEVERITY"
  [ -z "$sync" ] && continue

  info "$name"
  dir="$SETUP_DIR/$name"
  if [ ! -d "$dir/.git" ]; then
    warn "repo 없음 → 건너뜀 (먼저 ./bootstrap.sh)"
    [ "$effective_severity" = "required" ] && aggregate_fail=1
    continue
  fi

  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    warn "로컬 변경 있음 → sync 중단"
    [ "$effective_severity" = "required" ] && aggregate_fail=1
    continue
  fi

  # setup_cmd 와 달리 출력을 억제하지 않는다 (changelog·플러그인 복원 진행상황이 핵심).
  if ( cd "$dir" && eval "$sync" ); then
    ok "sync: $sync"
  else
    warn "sync 실패/부분: $sync (수동 확인)"
    [ "$effective_severity" = "required" ] && aggregate_fail=1
  fi
done < "$MANIFEST"

info "완료. 상태 점검: ./doctor.sh"
exit "$aggregate_fail"
