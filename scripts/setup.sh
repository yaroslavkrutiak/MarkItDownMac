#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing markitdown..."
pip install markitdown

echo ""
echo "==> Verifying installation..."
if command -v markitdown &>/dev/null; then
    echo "markitdown is installed at: $(which markitdown)"
    echo "Version: $(markitdown --version 2>/dev/null || echo 'unknown')"
else
    echo "Warning: markitdown is not on PATH."
    echo "You may need to add its install location to your PATH."
fi
