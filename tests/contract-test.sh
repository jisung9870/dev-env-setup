#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for child in binbox nvim cmux-config; do
  if [ ! -d "$child/.git" ]; then
    echo "required child repo missing: $child (run ./bootstrap.sh for this platform)" >&2
    exit 1
  fi
done

bash -n bootstrap.sh upgrade.sh doctor.sh lib/platform-selection.sh

for platform in macos linux windows-wsl; do
  bootstrap_selection="$(./bootstrap.sh --platform "$platform" --show-selection)"
  upgrade_selection="$(./upgrade.sh --platform "$platform" --show-selection)"
  doctor_selection="$(./doctor.sh --platform "$platform" --show-selection)"
  [ "$bootstrap_selection" = "$upgrade_selection" ] || {
    echo "bootstrap/upgrade selection mismatch: $platform" >&2
    exit 1
  }
  [ "$bootstrap_selection" = "$doctor_selection" ] || {
    echo "bootstrap/doctor selection mismatch: $platform" >&2
    exit 1
  }
done
printf 'platform selection: ok\n'

tests/failure-semantics-test.sh
tests/sessionizer-contract-test.sh
python3 cmux-config/scripts/check-references.py
python3 cmux-config/scripts/build-config.py --check
cmux-config/scripts/check-sensitive.sh

missing=0
while read -r command; do
  if [[ " setup list help doctor check new upgrade " == *" $command "* ]]; then
    continue
  fi
  if [ ! -f "binbox/libexec/$command" ] && [ ! -f "binbox/libexec/binbox-$command" ]; then
    echo "cmux references missing bb command: $command" >&2
    missing=1
  fi
done < <(grep -rhoE '\bbb [a-z0-9_-]+' cmux-config/config.d | awk '{print $2}' | sort -u)
[ "$missing" -eq 0 ]
printf 'cmux -> binbox commands: ok\n'

printf 'contract test: ok\n'
