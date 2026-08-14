#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="https://github.com/playbridgeapp/playbridge.git"
REF="${PLAYBRIDGE_REF:-main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${ROOT}/.build/playbridge"
DIST="${ROOT}/dist"

rm -rf "${WORK}"
mkdir -p "${ROOT}/.build" "${DIST}"

echo "==> Cloning PlayBridge (${REF})"
git clone --depth 1 "${UPSTREAM_URL}" "${WORK}"
cd "${WORK}"

if [[ "${REF}" != "main" ]]; then
  git fetch --depth 1 origin "${REF}"
  git checkout --detach FETCH_HEAD
fi

echo "==> Applying headless receiver patch"
git apply "${ROOT}/patches/headless-receiver.patch"

echo "==> Building PlayBridge CLI"
cargo build --release --manifest-path cli/Cargo.toml

cp cli/target/release/playbridge "${DIST}/playbridge"
chmod +x "${DIST}/playbridge"

echo
echo "Built: ${DIST}/playbridge"
echo "Run:   ${DIST}/playbridge receiver --headless"
