#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/workbench-failure.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

cp "$repo_root/bootstrap.sh" "$repo_root/upgrade.sh" "$tmp_root/"
mkdir -p "$tmp_root/lib" "$tmp_root/platforms" "$tmp_root/fixture"
cp "$repo_root/lib/platform-selection.sh" "$tmp_root/lib/"
printf 'fixture | | | false | false\n' >"$tmp_root/repos.txt"
for platform in macos linux windows-wsl; do
  printf '# schema-version: 1\nfixture required\n' >"$tmp_root/platforms/$platform.repos"
done

mkdir -p "$tmp_root/fixture/.git"
if "$tmp_root/bootstrap.sh" --platform linux --no-pull >/dev/null 2>&1; then
  echo "bootstrap returned success after a required setup failure" >&2
  exit 1
fi

rm -rf "$tmp_root/fixture/.git"
git -C "$tmp_root/fixture" init -q
printf 'fixture\n' >"$tmp_root/fixture/README"
git -C "$tmp_root/fixture" add README
git -C "$tmp_root/fixture" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm init
if "$tmp_root/upgrade.sh" --platform linux >/dev/null 2>&1; then
  echo "upgrade returned success after a required sync failure" >&2
  exit 1
fi

printf 'failure semantics: ok\n'
