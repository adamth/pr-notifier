#!/bin/bash

echo "🚀 Building PR Review Light for Sharing"
echo "======================================"
echo ""

# Clean up any existing builds
echo "🧹 Cleaning up previous builds..."
rm -rf .build PRReviewLight.app *.dmg temp-*.dmg
pkill -f PRReviewLight 2>/dev/null || true

# Build the app
echo "⚙️ Building Swift application..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Create app bundle
echo "📦 Creating macOS app bundle..."

APP_DIR="PRReviewLight.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/PRReviewLight "$MACOS_DIR/"
chmod +x "$MACOS_DIR/PRReviewLight"

# Copy app icon if it exists
if [ -f "AppIcon.png" ]; then
    echo "📱 Adding app icon..."
    cp AppIcon.png "$RESOURCES_DIR/"
elif [ -f "AppIcon.icns" ]; then
    echo "📱 Adding app icon..."
    cp AppIcon.icns "$RESOURCES_DIR/"
else
    echo "⚠️  No app icon found (AppIcon.png or AppIcon.icns)"
fi

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
    <key>CFBundleDisplayName</key>
    <string>PR Review Light</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 PR Review Light</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "✅ App bundle created!"
echo ""

# Create DMG
echo "💿 Creating DMG installer..."

DMG_NAME="PRReviewLight-v1.0"
TEMP_DMG="temp-${DMG_NAME}.dmg"
FINAL_DMG="${DMG_NAME}.dmg"

# Calculate size and create DMG
APP_SIZE=$(du -sm "$APP_DIR" | cut -f1)
DMG_SIZE=$((APP_SIZE + 15))

hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "PR Review Light" "$TEMP_DMG"
hdiutil attach "$TEMP_DMG" -mountpoint "/Volumes/PR Review Light"

# Copy app and create shortcuts
cp -R "$APP_DIR" "/Volumes/PR Review Light/"
ln -s /Applications "/Volumes/PR Review Light/Applications"

# Create installation instructions
cat > "/Volumes/PR Review Light/Installation Instructions.txt" << 'EOF'
🚀 PR Review Light Installation
===============================

INSTALL:
1. Drag "PR Review Light.app" to the Applications folder
2. Launch from Applications or Spotlight
3. The app appears in your menu bar

SETUP:
1. Click menu bar icon → Settings
2. Get GitHub Personal Access Token:
   • GitHub → Settings → Developer settings → Personal access tokens
   • Generate new token with "repo" and "read:user" scopes
3. Paste token → Save → Test Connection
4. Enable notifications when prompted

NOTIFICATIONS:
• The app will ask for notification permissions
• If denied, go to System Settings → Notifications → PR Review Light
• For unsigned apps, you may need to try 2-3 times

FEATURES:
• Shows pending PR reviews in menu bar
• Green checkmark = no reviews needed
• Orange triangle = reviews waiting!
• Click PR titles to open in browser
• Snooze reviews for 1 hour

Never miss a code review again! 🎯
EOF

# Finalize DMG
echo "💿 Finalizing DMG..."
hdiutil detach "/Volumes/PR Review Light" || echo "Volume already detached"
sleep 2
hdiutil convert "$TEMP_DMG" -format UDZO -o "$FINAL_DMG"
if [ $? -eq 0 ]; then
    rm -rf "$TEMP_DMG" "$APP_DIR"
else
    echo "⚠️ Conversion failed, keeping temp DMG as final"
    mv "$TEMP_DMG" "$FINAL_DMG"
fi

echo "✅ DMG created: $FINAL_DMG"
echo ""
echo "📤 Ready to Share!"
echo "=================="
echo "File to share: $FINAL_DMG"
echo "Size: $(du -h "$FINAL_DMG" | cut -f1)"
echo ""
echo "📋 Your colleagues should:"
echo "1. Download and open the DMG file"
echo "2. Drag the app to Applications"
echo "3. Launch and follow setup instructions"
echo ""
echo "⚠️  Note: Unsigned app - they'll need to right-click → Open first time"
echo ""
echo "🎉 Done! Share away!"