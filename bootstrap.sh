#!/usr/bin/env bash
#
# bootstrap.sh — 크로스-머신 개인 환경 프로비저닝 (멱등)
#
# repos.txt 매니페스트를 의존 순서대로 처리:
#   1) repo 없으면 clone, 있으면 (클린일 때만) pull --ff-only
#   2) link_target 심볼릭 링크 생성/갱신
#   3) setup_cmd (각 repo 자체 셋업) 실행
#
# 사용법:
#   ./bootstrap.sh                # 전체 프로비저닝
#   ./bootstrap.sh --no-pull      # clone/link/setup 만, 기존 repo pull 생략
#   ./bootstrap.sh --no-setup     # clone/pull/link 만, setup_cmd 생략
#   ./bootstrap.sh --link-only    # 심볼릭 링크만 재생성 (안전, 현재 장비 복구용)
#   ./bootstrap.sh binbox nvim    # 특정 repo만
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"

NO_PULL=0; NO_SETUP=0; LINK_ONLY=0; ONLY=()
for a in "$@"; do
  case "$a" in
    --no-pull)   NO_PULL=1 ;;
    --no-setup)  NO_SETUP=1 ;;
    --link-only) LINK_ONLY=1; NO_PULL=1; NO_SETUP=1 ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    -*)          echo "unknown option: $a" >&2; exit 2 ;;
    *)           ONLY+=("$a") ;;
  esac
done

info(){ printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

expand(){ printf '%s' "${1/#\~/$HOME}"; }
selected(){ [ ${#ONLY[@]} -eq 0 ] && return 0; local n; for n in "${ONLY[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

[ -f "$MANIFEST" ] || { echo "manifest 없음: $MANIFEST" >&2; exit 1; }

while IFS='|' read -r name url link setup || [ -n "$name" ]; do
  name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  url="$(echo "$url" | xargs)"; link="$(echo "$link" | xargs)"; setup="$(echo "$setup" | xargs)"
  selected "$name" || continue

  info "$name"
  dir="$SETUP_DIR/$name"

  # 1) clone / pull
  if [ ! -d "$dir/.git" ]; then
    if [ -n "$url" ]; then git clone "$url" "$dir" && ok "cloned $url"; else warn "repo 없음 & url 미정 → 건너뜀"; continue; fi
  elif [ "$NO_PULL" -eq 0 ]; then
    if [ -z "$(git -C "$dir" status --porcelain)" ]; then
      git -C "$dir" pull --ff-only >/dev/null 2>&1 && ok "pulled (ff)" || warn "pull 생략 (ff 불가/오프라인)"
    else
      warn "로컬 변경 있음 → pull 생략"
    fi
  fi

  # 2) 심볼릭 링크
  if [ -n "$link" ]; then
    tgt="$(expand "$link")"
    mkdir -p "$(dirname "$tgt")"
    ln -sfn "$dir" "$tgt"
    [ -e "$tgt" ] && ok "link $link → $name" || warn "link 실패: $link"
  fi

  # 3) 자체 setup
  if [ -n "$setup" ] && [ "$NO_SETUP" -eq 0 ]; then
    ( cd "$dir" && eval "$setup" ) >/dev/null 2>&1 && ok "setup: $setup" || warn "setup 실패/부분: $setup (수동 확인)"
  fi
done < "$MANIFEST"

info "완료. 상태 점검: ./doctor.sh"
