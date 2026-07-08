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
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"

ONLY=()
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*)        echo "unknown option: $a" >&2; exit 2 ;;
    *)         ONLY+=("$a") ;;
  esac
done

info(){ printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

selected(){ [ ${#ONLY[@]} -eq 0 ] && return 0; local n; for n in "${ONLY[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

[ -f "$MANIFEST" ] || { echo "manifest 없음: $MANIFEST" >&2; exit 1; }

while IFS='|' read -r name url link setup sync || [ -n "$name" ]; do
  name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  sync="$(echo "$sync" | xargs)"
  selected "$name" || continue
  [ -z "$sync" ] && continue

  info "$name"
  dir="$SETUP_DIR/$name"
  if [ ! -d "$dir/.git" ]; then warn "repo 없음 → 건너뜀 (먼저 ./bootstrap.sh)"; continue; fi

  # setup_cmd 와 달리 출력을 억제하지 않는다 (changelog·플러그인 복원 진행상황이 핵심).
  if ( cd "$dir" && eval "$sync" ); then ok "sync: $sync"; else warn "sync 실패/부분: $sync (수동 확인)"; fi
done < "$MANIFEST"

info "완료. 상태 점검: ./doctor.sh"
