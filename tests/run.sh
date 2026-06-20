#!/usr/bin/env bash
# Run all mini.test specs headlessly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve mini.nvim: allow override via MINI_PATH env var.
# Falls back to common lazy.nvim / packer locations.
if [ -z "${MINI_PATH:-}" ]; then
  for candidate in \
    "$HOME/.local/share/nvim/lazy/mini.nvim" \
    "$HOME/.local/share/nvim/site/pack/packer/start/mini.nvim"; do
    if [ -d "$candidate" ]; then
      MINI_PATH="$candidate"
      break
    fi
  done
fi

if [ -z "${MINI_PATH:-}" ]; then
  echo "mini.nvim not found. Set MINI_PATH=/path/to/mini.nvim or install it." >&2
  exit 1
fi

nvim --headless --noplugin \
  -u NONE \
  -c "set rtp+=${REPO_ROOT}" \
  -c "set rtp+=${MINI_PATH}" \
  -c "lua require('mini.test').setup()" \
  -c "lua MiniTest.run_file_at_cursor()" \
  -c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout() } })" \
  +qa 2>&1
