#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AgentWatch — build the macOS menu bar .app bundle
#
# Prerequisites: Xcode or Xcode Command Line Tools (swift build)
#
# Usage:
#   bash macos/build_app.sh
#
# Output:
#   build/AgentWatch.app
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SWIFT_PROJECT="$SCRIPT_DIR/AgentWatchMenuBar"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="AgentWatch"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_PROJECT_DIR="$APP_BUNDLE/Contents/Resources/AgentWatchProject"

echo "============================================"
echo "  AgentWatch — Building Menu Bar App"
echo "============================================"
echo ""

# --- 1. Swift build ---
echo "[1/6] Building Swift executable (release) ..."
cd "$SWIFT_PROJECT"
swift build -c release --disable-sandbox 2>&1
echo "      Done."

# Find the built binary
SWIFT_BIN=$(find "$SWIFT_PROJECT/.build" -path "*/release/AgentWatchMenuBar" -type f 2>/dev/null | head -1)
if [ -z "$SWIFT_BIN" ]; then
    echo "ERROR: Could not find built binary."
    exit 1
fi
echo "      Binary: $SWIFT_BIN"

# --- 2. Create .app bundle structure ---
echo "[2/6] Creating .app bundle structure ..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
echo "      $APP_BUNDLE"

# --- 3. Copy executable ---
echo "[3/6] Copying executable ..."
cp "$SWIFT_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo "      Done."

# --- 4. Bundle AgentWatch project files ---
echo "[4/6] Bundling AgentWatch project files ..."
mkdir -p "$APP_PROJECT_DIR"
mkdir -p "$APP_PROJECT_DIR/logs"
cp "$PROJECT_DIR/pyproject.toml" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/config.example.json" "$APP_PROJECT_DIR/config.json"
cp "$PROJECT_DIR/README.md" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/README_CN.md" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/LICENSE" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/install_claude_hooks.sh" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/uninstall_claude_hooks.sh" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/install_codex_hooks.sh" "$APP_PROJECT_DIR/"
cp "$PROJECT_DIR/uninstall_codex_hooks.sh" "$APP_PROJECT_DIR/"
rsync -a --exclude='__pycache__' --exclude='*.pyc' "$PROJECT_DIR/agentwatch/" "$APP_PROJECT_DIR/agentwatch/"
chmod +x "$APP_PROJECT_DIR/install_claude_hooks.sh" \
         "$APP_PROJECT_DIR/uninstall_claude_hooks.sh" \
         "$APP_PROJECT_DIR/install_codex_hooks.sh" \
         "$APP_PROJECT_DIR/uninstall_codex_hooks.sh"
echo "      $APP_PROJECT_DIR"

# --- 5. Write Info.plist ---
echo "[5/6] Writing Info.plist ..."
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>AgentWatch</string>
    <key>CFBundleDisplayName</key>
    <string>AgentWatch</string>
    <key>CFBundleIdentifier</key>
    <string>com.agentwatch.menubar</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>AgentWatch</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST_EOF
echo "      Done."

# --- 6. Verify ---
echo "[6/6] Verifying bundle ..."
echo "      $(ls -la "$APP_BUNDLE/Contents/MacOS/$APP_NAME")"
echo "      Bundled project: $(ls -la "$APP_PROJECT_DIR/pyproject.toml")"
echo "      LSUIElement: $(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo 'true')"

echo ""
echo "============================================"
echo "  Build Complete"
echo "============================================"
echo ""
echo "  App:  $APP_BUNDLE"
echo ""
echo "  To launch:"
echo "    open '$APP_BUNDLE'"
echo "    or double-click 'Open AgentWatch App.command'"
echo ""
echo "  The app runs in the menu bar (no Dock icon)."
echo "  Look for '● AW' in the top-right of your screen."
echo ""
