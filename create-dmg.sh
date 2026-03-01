#!/bin/bash
# ============================================================================
# RamDoubler X — DMG Installer Builder
# ============================================================================
# Creates a styled DMG with drag-to-install layout.
# Requires: create-dmg (brew install create-dmg)
#
# Usage:
#   ./create-dmg.sh                     # uses Release build from DerivedData
#   ./create-dmg.sh /path/to/App.app    # uses specified app bundle
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="RamDoubler X"
DMG_NAME="RamDoubler_X.dmg"
VOLUME_NAME="RamDoubler X"
OUTPUT_DMG="${SCRIPT_DIR}/${DMG_NAME}"
SIGN_IDENTITY="Developer ID Application: Sky Benson (KR6GAN67JK)"

# ── Locate the app bundle ───────────────────────────────────────
if [ -n "$1" ]; then
    APP_PATH="$1"
else
    # Find the Release build in DerivedData
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
        -path "*/RamDoubler*/Build/Products/Release/${APP_NAME}.app" \
        -type d 2>/dev/null | head -1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_NAME}.app"
    echo "Build the Release target in Xcode first, or pass the path as an argument."
    exit 1
fi

echo "App: ${APP_PATH}"

# ── Verify code signature ───────────────────────────────────────
echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH" 2>&1 || {
    echo "Error: App has invalid code signature."
    exit 1
}
echo "Code signature valid."

# ── Remove old DMG if present ───────────────────────────────────
if [ -f "$OUTPUT_DMG" ]; then
    echo "Removing existing DMG..."
    rm "$OUTPUT_DMG"
fi

# ── Create DMG ──────────────────────────────────────────────────
echo "Creating DMG installer..."

create-dmg \
    --volname "$VOLUME_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$OUTPUT_DMG" \
    "$APP_PATH"

# ── Sign the DMG ────────────────────────────────────────────────
echo "Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"

echo ""
echo "================================"
echo "DMG created: ${OUTPUT_DMG}"
echo "Size: $(du -h "$OUTPUT_DMG" | cut -f1)"
echo "================================"
