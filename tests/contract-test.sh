#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_ONLY=0
[ "${1:-}" != "--root-only" ] || ROOT_ONLY=1
tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf '[PASS] %s\n' "$1"; }
die() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_contains() { printf '%s\n' "$1" | grep -Fq "$2" || die "$3 (missing: $2)"; }
assert_same() { [ "$1" = "$2" ] || die "$3"; }
assert_file_contains() { grep -Fq -- "$2" "$1" || die "$3 (missing: $2)"; }

for file in bootstrap.sh upgrade.sh doctor.sh lib/repo-selector.sh lib/repo-lock.sh; do
  bash -n "$ROOT/$file"
done
pass 'root shell syntax'

for platform in macos linux windows-wsl; do
  bootstrap_selection="$("$ROOT/bootstrap.sh" --platform "$platform" --show-selection)"
  upgrade_selection="$("$ROOT/upgrade.sh" --platform "$platform" --show-selection)"
  doctor_selection="$("$ROOT/doctor.sh" --platform "$platform" --show-selection)"
  assert_same "$bootstrap_selection" "$upgrade_selection" "$platform bootstrap/upgrade selection drift"
  assert_same "$bootstrap_selection" "$doctor_selection" "$platform bootstrap/doctor selection drift"
done
pass 'all entrypoints share byte-identical selection output'

flag_priority="$(WB_PLATFORM=linux "$ROOT/bootstrap.sh" --platform macos --show-selection | sed -n '1p')"
env_priority="$(WB_PLATFORM=linux "$ROOT/bootstrap.sh" --show-selection | sed -n '1p')"
assert_same "$flag_priority" 'platform|macos' 'explicit platform did not override WB_PLATFORM'
assert_same "$env_priority" 'platform|linux' 'WB_PLATFORM was not honored'
darwin_detect="$(bash -c 'source "$1"; wb_selector_detect_platform Darwin 23.0.0 ""' bash "$ROOT/lib/repo-selector.sh")"
linux_detect="$(bash -c 'source "$1"; wb_selector_detect_platform Linux 6.8.0 ""' bash "$ROOT/lib/repo-selector.sh")"
wsl_detect="$(bash -c 'source "$1"; wb_selector_detect_platform Linux 6.8.0-microsoft-standard ""' bash "$ROOT/lib/repo-selector.sh")"
wsl_marker_detect="$(bash -c 'source "$1"; wb_selector_detect_platform Linux 6.8.0 /run/WSL/1_interop' bash "$ROOT/lib/repo-selector.sh")"
assert_same "$darwin_detect" macos 'Darwin detection failed'
assert_same "$linux_detect" linux 'Linux detection failed'
assert_same "$wsl_detect" windows-wsl 'WSL kernel detection failed'
assert_same "$wsl_marker_detect" windows-wsl 'WSL marker detection failed'
if bash -c 'source "$1"; wb_selector_detect_platform Plan9 unknown ""' bash "$ROOT/lib/repo-selector.sh" >/dev/null 2>&1; then
  die 'unknown platform detection succeeded'
fi
pass 'platform detection priority and fallbacks'

macos_selection="$("$ROOT/bootstrap.sh" --platform macos --show-selection)"
linux_selection="$("$ROOT/bootstrap.sh" --platform linux --show-selection)"
assert_contains "$macos_selection" 'repo|cmux-config|optional|selected|optional|platform-default' 'macOS cmux severity'
assert_contains "$linux_selection" 'repo|cmux-config|disabled|skipped|disabled|platform-disabled' 'Linux cmux severity'
assert_contains "$linux_selection" 'repo|workbench|required|selected|required|platform-default' 'Workbench required selection'
pass 'platform severity defaults'

explicit_selection="$("$ROOT/bootstrap.sh" --platform linux cmux-config --show-selection)"
assert_contains "$explicit_selection" 'repo|cmux-config|disabled|selected|required|positional' 'explicit disabled repo promotion'
with_selection="$("$ROOT/bootstrap.sh" --platform macos --with cmux-config --show-selection)"
assert_contains "$with_selection" 'repo|cmux-config|optional|selected|required|with' '--with promotion'
without_selection="$("$ROOT/bootstrap.sh" --platform macos --without cmux-config --show-selection)"
assert_contains "$without_selection" 'repo|cmux-config|optional|skipped|optional|without' 'optional --without output'
if "$ROOT/bootstrap.sh" --platform macos unknown-repo --show-selection >/dev/null 2>&1; then
  die 'unknown explicit repository succeeded'
fi
if "$ROOT/bootstrap.sh" --platform macos --without binbox --show-selection >/dev/null 2>&1; then
  die 'required repo exclusion succeeded'
fi
if "$ROOT/bootstrap.sh" --platform macos --with cmux-config --without cmux-config --show-selection >/dev/null 2>&1; then
  die 'include/exclude conflict succeeded'
fi
pass 'selection precedence and conflict rules'

fixture="$tmp_dir/selector"
mkdir -p "$fixture/platforms"
printf 'one | https://example.invalid/one.git | | true | true\ntwo | https://example.invalid/two.git | | true | true\n' >"$fixture/repos.txt"
printf 'one required\n' >"$fixture/platforms/macos.repos"
if bash -c 'set -euo pipefail; source "$1"; wb_selector_init; WB_SELECTOR_PLATFORM_OPTION=macos; wb_selector_resolve "$2"' bash "$ROOT/lib/repo-selector.sh" "$fixture" >/dev/null 2>&1; then
  die 'incomplete platform projection succeeded'
fi
printf 'one required\ntwo invalid\n' >"$fixture/platforms/macos.repos"
if bash -c 'set -euo pipefail; source "$1"; wb_selector_init; WB_SELECTOR_PLATFORM_OPTION=macos; wb_selector_resolve "$2"' bash "$ROOT/lib/repo-selector.sh" "$fixture" >/dev/null 2>&1; then
  die 'invalid severity succeeded'
fi
printf 'one required\none optional\n' >"$fixture/platforms/macos.repos"
if bash -c 'set -euo pipefail; source "$1"; wb_selector_init; WB_SELECTOR_PLATFORM_OPTION=macos; wb_selector_resolve "$2"' bash "$ROOT/lib/repo-selector.sh" "$fixture" >/dev/null 2>&1; then
  die 'duplicate profile row succeeded'
fi
pass 'profile schema and totality validation'

printf 'one | | | true | true\n' >"$fixture/repos.txt"
printf 'one required\n' >"$fixture/platforms/macos.repos"
if bash -c 'set -euo pipefail; source "$1"; wb_selector_init; WB_SELECTOR_PLATFORM_OPTION=macos; wb_selector_resolve "$2"' bash "$ROOT/lib/repo-selector.sh" "$fixture" >/dev/null 2>&1; then
  die 'empty manifest URL succeeded'
fi
printf 'one | https://example.invalid/one.git | | true | true | extra\n' >"$fixture/repos.txt"
if bash -c 'set -euo pipefail; source "$1"; wb_selector_init; WB_SELECTOR_PLATFORM_OPTION=macos; wb_selector_resolve "$2"' bash "$ROOT/lib/repo-selector.sh" "$fixture" >/dev/null 2>&1; then
  die 'malformed six-field manifest row succeeded'
fi
pass 'manifest row shape and required URL validation'

source "$ROOT/lib/repo-lock.sh"
wb_lock_validate "$ROOT"
lock_fixture="$tmp_dir/lock"
mkdir -p "$lock_fixture/locks"
printf 'one | https://example.invalid/one.git | | true | true\n' >"$lock_fixture/repos.txt"
printf 'one not-a-sha\n' >"$lock_fixture/locks/repos.lock"
if wb_lock_validate "$lock_fixture" >/dev/null 2>&1; then die 'invalid lock SHA succeeded'; fi
printf 'other 0123456789012345678901234567890123456789\n' >"$lock_fixture/locks/repos.lock"
if wb_lock_validate "$lock_fixture" >/dev/null 2>&1; then die 'unknown lock repo succeeded'; fi
printf 'one 0123456789012345678901234567890123456789\none 0123456789012345678901234567890123456789\n' >"$lock_fixture/locks/repos.lock"
if wb_lock_validate "$lock_fixture" >/dev/null 2>&1; then die 'duplicate lock repo succeeded'; fi
: >"$lock_fixture/locks/repos.lock"
if wb_lock_validate "$lock_fixture" >/dev/null 2>&1; then die 'missing lock repo succeeded'; fi
mkdir -p "$lock_fixture/one"
git -C "$lock_fixture/one" init -q
printf 'fixture\n' >"$lock_fixture/one/file"
git -C "$lock_fixture/one" add file
git -C "$lock_fixture/one" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m initial
lock_head_before="$(git -C "$lock_fixture/one" rev-parse HEAD)"
printf 'one 0000000000000000000000000000000000000000\n' >"$lock_fixture/locks/repos.lock"
lock_report="$(wb_lock_report "$lock_fixture")"
assert_contains "$lock_report" 'snapshot|one|mismatch|0000000000000000000000000000000000000000|' 'checkout mismatch was not reported'
assert_same "$(git -C "$lock_fixture/one" rev-parse HEAD)" "$lock_head_before" 'lock report mutated checkout HEAD'
pass 'repository lock schema validation'

orchestration="$tmp_dir/orchestration"
mkdir -p "$orchestration/lib" "$orchestration/platforms" "$orchestration/required-repo" "$orchestration/optional-repo"
cp "$ROOT/bootstrap.sh" "$ROOT/upgrade.sh" "$orchestration/"
cp "$ROOT/lib/repo-selector.sh" "$orchestration/lib/"
git -C "$orchestration/required-repo" init -q
git -C "$orchestration/optional-repo" init -q
printf '#!/bin/sh\nexit 9\n' >"$orchestration/required-repo/setup.sh"
printf '#!/bin/sh\nexit 9\n' >"$orchestration/optional-repo/setup.sh"
printf 'required-repo | https://example.invalid/required.git | | sh setup.sh | sh setup.sh\noptional-repo | https://example.invalid/optional.git | | sh setup.sh | sh setup.sh\n' >"$orchestration/repos.txt"
printf 'required-repo required\noptional-repo optional\n' >"$orchestration/platforms/macos.repos"
if "$orchestration/bootstrap.sh" --platform macos --no-pull >/dev/null 2>&1; then die 'required setup failure returned success'; fi
if "$orchestration/upgrade.sh" --platform macos >/dev/null 2>&1; then die 'required sync failure returned success'; fi
printf '#!/bin/sh\nexit 0\n' >"$orchestration/required-repo/setup.sh"
"$orchestration/bootstrap.sh" --platform macos --no-pull >/dev/null 2>&1 || die 'optional setup failure made aggregate fail'
"$orchestration/upgrade.sh" --platform macos >/dev/null 2>&1 || die 'optional sync failure made aggregate fail'
if "$orchestration/bootstrap.sh" --platform macos --with optional-repo --no-pull >/dev/null 2>&1; then die 'explicit optional setup failure returned success'; fi
if "$orchestration/upgrade.sh" --platform macos --with optional-repo >/dev/null 2>&1; then die 'explicit optional sync failure returned success'; fi
pass 'required and optional child failure semantics'

clone_fixture="$tmp_dir/clone-failure"
mkdir -p "$clone_fixture/lib" "$clone_fixture/platforms"
cp "$ROOT/bootstrap.sh" "$clone_fixture/"
cp "$ROOT/lib/repo-selector.sh" "$clone_fixture/lib/"
printf 'required-repo | /definitely/missing/workbench-contract.git | | true | true\n' >"$clone_fixture/repos.txt"
printf 'required-repo required\n' >"$clone_fixture/platforms/macos.repos"
if "$clone_fixture/bootstrap.sh" --platform macos --no-pull >/dev/null 2>&1; then die 'required clone failure returned success'; fi

pull_fixture="$tmp_dir/pull-failure"
mkdir -p "$pull_fixture/lib" "$pull_fixture/platforms" "$pull_fixture/required-repo"
cp "$ROOT/bootstrap.sh" "$pull_fixture/"
cp "$ROOT/lib/repo-selector.sh" "$pull_fixture/lib/"
git -C "$pull_fixture/required-repo" init -q
printf 'fixture\n' >"$pull_fixture/required-repo/file"
git -C "$pull_fixture/required-repo" add file
git -C "$pull_fixture/required-repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m initial
printf '#!/bin/sh\nprintf continued >../continued\n' >"$pull_fixture/required-repo/setup.sh"
printf 'required-repo | https://example.invalid/required.git | | sh setup.sh | true\n' >"$pull_fixture/repos.txt"
printf 'required-repo required\n' >"$pull_fixture/platforms/macos.repos"
if "$pull_fixture/bootstrap.sh" --platform macos >/dev/null 2>&1; then die 'required pull failure returned success'; fi
[ -f "$pull_fixture/continued" ] || die 'bootstrap stopped processing after pull failure'
pass 'required clone and pull failures remain observable'

doctor_fixture="$tmp_dir/doctor-corrupt"
mkdir -p "$doctor_fixture/lib" "$doctor_fixture/platforms" "$doctor_fixture/locks" "$doctor_fixture/one/.git"
cp "$ROOT/doctor.sh" "$doctor_fixture/"
cp "$ROOT/lib/repo-selector.sh" "$ROOT/lib/repo-lock.sh" "$doctor_fixture/lib/"
printf 'one | https://example.invalid/one.git | | true | true\n' >"$doctor_fixture/repos.txt"
printf 'one required\n' >"$doctor_fixture/platforms/macos.repos"
printf 'one 0000000000000000000000000000000000000000\n' >"$doctor_fixture/locks/repos.lock"
if "$doctor_fixture/doctor.sh" --platform macos >/dev/null 2>&1; then die 'corrupt required checkout was reported healthy'; fi
pass 'doctor rejects unreadable required Git checkout'

nvim_link="$(awk -F'|' '$1 ~ /^[[:space:]]*nvim[[:space:]]*$/ {gsub(/[[:space:]]/, "", $3); print $3}' "$ROOT/repos.txt")"
cmux_link="$(awk -F'|' '$1 ~ /^[[:space:]]*cmux-config[[:space:]]*$/ {gsub(/[[:space:]]/, "", $3); print $3}' "$ROOT/repos.txt")"
binbox_link="$(awk -F'|' '$1 ~ /^[[:space:]]*binbox[[:space:]]*$/ {gsub(/[[:space:]]/, "", $3); print $3}' "$ROOT/repos.txt")"
expected_binbox_link="$(printf '\176/binbox')"
[ -z "$nvim_link" ] && [ -z "$cmux_link" ] && [ "$binbox_link" = "$expected_binbox_link" ] || die 'runtime link ownership does not match ADR-005'
grep -Eq '^workbench[[:space:]]*\|' "$ROOT/repos.txt" || die 'workbench missing from manifest'
pass 'runtime link ownership and Workbench manifest integration'

for child in binbox nvim cmux-config workbench; do
  [ -d "$ROOT/$child/.git" ] || die "missing child repository '$child'; run ./bootstrap.sh"
done

tmux_config="$ROOT/nvim/scripts/config/.tmux.conf"
assert_file_contains "$tmux_config" 'bind | split-window -h -c "#{pane_current_path}"' 'tmux horizontal split binding changed'
assert_file_contains "$tmux_config" 'bind - split-window -v -c "#{pane_current_path}"' 'tmux vertical split binding changed'
assert_file_contains "$tmux_config" 'bind c new-window -c "#{pane_current_path}"' 'tmux new-window binding changed'
assert_file_contains "$tmux_config" 'bind f run-shell "tmux neww '\''bb tm'\''"' 'tmux project sessionizer binding changed'
assert_file_contains "$tmux_config" 'bind a display-popup -E -w 85% -h 70% "bb agents"' 'tmux Agent popup binding changed'
pass 'terminal-first tmux keybindings remain stable'

assert_file_contains "$ROOT/nvim/lua/plugins/terminal.lua" '"<leader>tp",' 'LazyVim tmux project keybinding changed'
assert_file_contains "$ROOT/nvim/lua/plugins/terminal.lua" 'cmd = "bb tm",' 'LazyVim tmux project command changed'
assert_file_contains "$ROOT/nvim/lua/plugins/editor.lua" '"<leader>fp",' 'LazyVim Workbench project keybinding changed'
assert_file_contains "$ROOT/nvim/lua/plugins/editor.lua" 'require("workbench.projects").pick()' 'LazyVim Workbench project picker changed'
pass 'LazyVim project entrypoints remain stable'

bb_tools="$($ROOT/binbox/bb list)"
for tool in tm agents gx kx assume assm tfx tvx dx portcheck md2jira wenv sec; do
  assert_contains "$bb_tools" "$tool" "binbox toolbox command '$tool' unavailable"
  [ -x "$ROOT/binbox/libexec/$tool" ] || die "binbox toolbox command '$tool' is not executable"
done
pass 'binbox toolbox entrypoints remain available without Workbench'

# Assert navigation integrity of the plan package, not prose wording: paths and
# filenames are stable, while any rewording of a sentence would break the suite.
[ -f "$ROOT/plan/09-product-plan.md" ] || die 'plan/09-product-plan.md is missing'
assert_file_contains "$ROOT/plan/README.md" '09-product-plan.md' 'plan/README.md no longer links the product baseline document'
assert_file_contains "$ROOT/WORKBENCH-PLAN.md" 'plan/README.md' 'WORKBENCH-PLAN.md no longer points at the plan package'
pass 'plan package entry points remain linked'

session_root="$tmp_dir/sessionizer"
mkdir -p "$session_root/parent/alpha" "$session_root/parent/space project" "$session_root/parent/.hidden" "$session_root/direct"
sed "s|__ROOT__|$session_root|g" "$ROOT/tests/fixtures/sessionizer/dirs" >"$session_root/dirs"
sed "s|__ROOT__|$session_root|g" "$ROOT/tests/fixtures/sessionizer/expected-projects" >"$session_root/expected"
mkdir -p "$session_root/config/tmux-sessionizer"
cp "$session_root/dirs" "$session_root/config/tmux-sessionizer/dirs"
XDG_CONFIG_HOME="$session_root/config" "$ROOT/binbox/libexec/tm" projects --plain | sort >"$session_root/binbox.out"
cmp "$session_root/expected" "$session_root/binbox.out" || die 'binbox sessionizer fixture mismatch'
if command -v nvim >/dev/null 2>&1; then
  nvim --headless -u NONE -l "$ROOT/nvim/scripts/sessionizer-projects.lua" "$session_root/dirs" | sort >"$session_root/nvim.out"
  cmp "$session_root/expected" "$session_root/nvim.out" || die 'nvim sessionizer fixture mismatch'
else
  die 'nvim is required for aggregate sessionizer contract; run child setup first'
fi
pass 'binbox and nvim sessionizer project sets match'

if [ "$ROOT_ONLY" -eq 0 ]; then
  make -C "$ROOT/binbox" ci
  "$ROOT/nvim/scripts/test-setup.sh"
  "$ROOT/cmux-config/scripts/check-config.sh"
  (cd "$ROOT/workbench" && go test ./...)
  pass 'child repository aggregate tests'
fi

printf 'contract tests passed: %s groups\n' "$pass_count"
