#!/usr/bin/env bash
#
# Generates the MarkItDownMac.xcodeproj without requiring Xcode's GUI.
# Requires: xcodegen (brew install xcodegen)
#
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen &>/dev/null; then
    echo "xcodegen is not installed. Install it with:"
    echo "  brew install xcodegen"
    echo ""
    echo "Alternatively, open Xcode → File → New Project → macOS App,"
    echo "then drag the App/, Bridge/, Core/, UI/ folders into the project."
    exit 1
fi

xcodegen generate
echo "==> MarkItDownMac.xcodeproj generated. Open it in Xcode."
