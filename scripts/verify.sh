#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="${ROOT}/patches/headless-receiver.patch"
README="${ROOT}/README.md"
ENGINEERING="${ROOT}/ENGINEERING.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -s "${PATCH}" ]] || fail "missing headless receiver patch"
[[ -s "${README}" ]] || fail "missing README"
[[ -s "${ENGINEERING}" ]] || fail "missing engineering notes"

grep -q -- 'run_receiver_mode' "${PATCH}" || fail "patch does not touch receiver runtime"
grep -q -- --headless "${PATCH}" || fail "patch does not add --headless"
grep -q -- 'receiver --headless' "${README}" || fail "README missing headless invocation"
grep -q -- 'strace' "${ENGINEERING}" || fail "engineering notes missing investigation evidence"
grep -q -- 'TIOCGWINSZ' "${ENGINEERING}" || fail "engineering notes missing terminal syscall evidence"

if grep -q -- '--no-tui' "${README}"; then
  echo "note: README references the removed upstream --no-tui option as historical context"
fi

echo "Repository checks passed."
