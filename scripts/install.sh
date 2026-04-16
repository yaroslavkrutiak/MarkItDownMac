#!/usr/bin/env bash
#
# Install MarkItDownMac from the latest GitHub release.
# Downloads, extracts, strips quarantine, and copies to /Applications.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/yaroslavkrutiak/MarkItDownMac/main/scripts/install.sh | bash
#
set -euo pipefail

REPO="yaroslavkrutiak/MarkItDownMac"
APP_NAME="MarkItDownMac"
INSTALL_DIR="/Applications"

echo "==> Fetching latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"browser_download_url".*\.zip"' \
  | head -1 \
  | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: no release found at $REPO. Create a release first."
    exit 1
fi

VERSION=$(echo "$DOWNLOAD_URL" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "latest")
echo "==> Downloading $APP_NAME $VERSION..."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

curl -fSL -o "$WORK/$APP_NAME.zip" "$DOWNLOAD_URL"

echo "==> Extracting..."
ditto -x -k "$WORK/$APP_NAME.zip" "$WORK"

echo "==> Removing quarantine attribute..."
xattr -cr "$WORK/$APP_NAME.app"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "==> Replacing existing installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "==> Installing to $INSTALL_DIR..."
mv "$WORK/$APP_NAME.app" "$INSTALL_DIR/"

echo ""
echo "Done! $APP_NAME installed at $INSTALL_DIR/$APP_NAME.app"
echo "Launch it from Applications or Spotlight."
