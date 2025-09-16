#!/bin/bash

# PR Review Light Installer
# Installs PR Review Light to /Applications and sets up launch agent

set -e

echo "🚀 Installing PR Review Light..."

# Check if we have a built binary
if [ ! -f ".build/release/PRReviewLight" ]; then
    echo "📦 Building PR Review Light..."
    swift build -c release
fi

# Create app bundle structure
APP_DIR="PRReviewLight.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "📁 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

# Copy binary
cp .build/release/PRReviewLight "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PRReviewLight</string>
    <key>CFBundleIdentifier</key>
    <string>com.prreviewlight.app</string>
    <key>CFBundleName</key>
    <string>PR Review Light</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy to Applications
echo "📱 Installing to Applications..."
if [ -d "/Applications/$APP_DIR" ]; then
    echo "⚠️  Existing installation found, removing..."
    rm -rf "/Applications/$APP_DIR"
fi

cp -R "$APP_DIR" /Applications/

echo "✅ Installation complete!"
echo ""
echo "🔧 To set up your GitHub token:"
echo "1. Launch PR Review Light from Applications"
echo "2. Click the menu bar icon → Settings"
echo "3. Enter your GitHub Personal Access Token"
echo "4. Click Save and Test Connection"
echo ""
echo "📋 To create a GitHub token:"
echo "1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)"
echo "2. Generate new token with scopes: 'repo' and 'read:user'"
echo ""
echo "🎉 PR Review Light is ready to use!"