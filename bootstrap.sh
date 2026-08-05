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
#   ./bootstrap.sh --show-selection
#   ./bootstrap.sh --platform windows-wsl [--without cmux-config]
#
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SETUP_DIR/repos.txt"
WB_SETUP_DIR="$SETUP_DIR"
WB_MANIFEST="$MANIFEST"
# shellcheck source=lib/platform-selection.sh
source "$SETUP_DIR/lib/platform-selection.sh"

NO_PULL=0; NO_SETUP=0; SHOW_SELECTION=0; PLATFORM_OVERRIDE=""
WB_ONLY=(); WB_WITHOUT=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-pull)   NO_PULL=1 ;;
    --no-setup)  NO_SETUP=1 ;;
    --link-only) NO_PULL=1; NO_SETUP=1 ;;
    --show-selection) SHOW_SELECTION=1 ;;
    --platform)
      [ "$#" -ge 2 ] || { echo "--platform 값이 필요합니다" >&2; exit 2; }
      PLATFORM_OVERRIDE="$2"; shift ;;
    --without)
      [ "$#" -ge 2 ] || { echo "--without repo 이름이 필요합니다" >&2; exit 2; }
      WB_WITHOUT+=("$2"); shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           WB_ONLY+=("$1") ;;
  esac
  shift
done

info(){ printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }

expand(){ printf '%s' "${1/#\~/$HOME}"; }
[ -f "$MANIFEST" ] || { echo "manifest 없음: $MANIFEST" >&2; exit 1; }
wb_prepare_selection "$PLATFORM_OVERRIDE"
if [ "$SHOW_SELECTION" -eq 1 ]; then
  wb_show_selection
  exit $?
fi

aggregate_fail=0
info "platform: $WB_PLATFORM_ID"

while IFS='|' read -r name url link setup _sync || [ -n "$name" ]; do
  name="$(echo "$name" | xargs)"; [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  url="$(echo "$url" | xargs)"; link="$(echo "$link" | xargs)"; setup="$(echo "$setup" | xargs)"
  severity="$(wb_profile_severity "$name")"
  wb_decide_repo "$name" "$severity"
  [ "$WB_SELECTED" -eq 1 ] || continue
  effective_severity="$WB_EFFECTIVE_SEVERITY"

  info "$name"
  dir="$SETUP_DIR/$name"

  # 1) clone / pull
  if [ ! -d "$dir/.git" ]; then
    if [ -n "$url" ]; then
      if git clone "$url" "$dir"; then
        ok "cloned $url"
      else
        warn "clone 실패: $url"
        [ "$effective_severity" = "required" ] && aggregate_fail=1
        continue
      fi
    else
      warn "repo 없음 & url 미정 → 건너뜀"
      [ "$effective_severity" = "required" ] && aggregate_fail=1
      continue
    fi
  elif [ "$NO_PULL" -eq 0 ]; then
    if [ -z "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
      if git -C "$dir" pull --ff-only >/dev/null 2>&1; then
        ok "pulled (ff)"
      else
        warn "pull 실패 (ff 불가/오프라인; --no-pull로 명시적 생략 가능)"
        [ "$effective_severity" = "required" ] && aggregate_fail=1
      fi
    else
      warn "로컬 변경 있음 → pull 생략"
    fi
  fi

  # 2) 심볼릭 링크
  if [ -n "$link" ]; then
    tgt="$(expand "$link")"
    if mkdir -p "$(dirname "$tgt")" && ln -sfn "$dir" "$tgt" && [ -e "$tgt" ]; then
      ok "link $link → $name"
    else
      warn "link 실패: $link"
      [ "$effective_severity" = "required" ] && aggregate_fail=1
    fi
  fi

  # 3) 자체 setup
  if [ -n "$setup" ] && [ "$NO_SETUP" -eq 0 ]; then
    if ( cd "$dir" && eval "$setup" ) >/dev/null 2>&1; then
      ok "setup: $setup"
    else
      warn "setup 실패/부분: $setup (수동 확인)"
      [ "$effective_severity" = "required" ] && aggregate_fail=1
    fi
  fi
done < "$MANIFEST"

info "완료. 상태 점검: ./doctor.sh"
exit "$aggregate_fail"
