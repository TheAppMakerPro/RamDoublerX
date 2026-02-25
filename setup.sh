#!/bin/bash
# ============================================================================
# RamDoubler X — Xcode Project Setup Script
# ============================================================================
# Run this on your Mac Mini M4 to set up the Xcode project.
# Requires: Xcode 15+ and Command Line Tools
#
# Usage: chmod +x setup.sh && ./setup.sh
# ============================================================================

set -e

echo "🧠 RamDoubler X — Project Setup"
echo "================================"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Install from App Store."
    exit 1
fi

XCODE_VER=$(xcodebuild -version | head -1)
echo "✅ Found: $XCODE_VER"

# ── Create Xcode Project via xcodegen ──────────────────────────
# Option A: If xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "📦 Generating Xcode project with xcodegen..."
    
    cat > project.yml << 'XCODEGEN_SPEC'
name: RamDoubler
options:
  bundleIdPrefix: com.ramdoubler
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    ARCHS: arm64
    PRODUCT_NAME: "RamDoubler X"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Automatic

targets:
  RamDoubler:
    type: application
    platform: macOS
    sources:
      - path: RamDoubler
        type: group
    settings:
      base:
        INFOPLIST_FILE: RamDoubler/Info.plist
        CODE_SIGN_ENTITLEMENTS: RamDoubler/RamDoubler.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.ramdoubler.app
        LD_RUNPATH_SEARCH_PATHS: "@executable_path/../Frameworks"
        ENABLE_HARDENED_RUNTIME: YES
        COMBINE_HIDPI_IMAGES: YES
XCODEGEN_SPEC

    xcodegen generate
    echo "✅ Xcode project generated!"
    
else
    echo ""
    echo "📋 xcodegen not found. Install it for auto-setup:"
    echo "   brew install xcodegen"
    echo ""
    echo "Or create the project manually (see README.md)"
fi

echo ""
echo "================================"
echo "🚀 Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open RamDoubler.xcodeproj in Xcode"
echo "  2. Select your Apple ID for signing"
echo "  3. Build & Run (⌘R)"
echo ""
echo "NOTE: The app needs to run WITHOUT sandbox to access"
echo "Mach VM statistics and run the purge command."
echo "================================"
