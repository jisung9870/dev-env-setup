#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$repo_root/tests/fixtures/sessionizer"
tmp_base="${TMPDIR:-/tmp}"
tmp_root="$(mktemp -d "${tmp_base%/}/workbench-sessionizer.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p \
  "$tmp_root/parent/alpha" \
  "$tmp_root/parent/space project" \
  "$tmp_root/parent/.hidden" \
  "$tmp_root/direct"

sed "s|__ROOT__|$tmp_root|g" "$fixture_dir/dirs" >"$tmp_root/dirs"
sed "s|__ROOT__|$tmp_root|g" "$fixture_dir/expected-projects" | sort >"$tmp_root/expected"
mkdir -p "$tmp_root/config/tmux-sessionizer"
cp "$tmp_root/dirs" "$tmp_root/config/tmux-sessionizer/dirs"

XDG_CONFIG_HOME="$tmp_root/config" \
  "$repo_root/binbox/libexec/tm" projects --plain | sort >"$tmp_root/binbox"

NVIM_LOG_FILE=/dev/null nvim --headless -u NONE \
  -l "$repo_root/nvim/scripts/sessionizer-projects.lua" "$tmp_root/dirs" | sort >"$tmp_root/nvim"

diff -u "$tmp_root/expected" "$tmp_root/binbox"
diff -u "$tmp_root/expected" "$tmp_root/nvim"
printf 'sessionizer contract: ok\n'
