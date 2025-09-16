#!/bin/bash

# Create a professional macOS DMG installer for PR Review Light

set -e

echo "💿 Creating PR Review Light DMG installer..."

APP_NAME="PR Review Light"
APP_DIR="PRReviewLight.app"
DMG_NAME="PRReviewLight-v1.0"
TEMP_DMG="temp-${DMG_NAME}.dmg"
FINAL_DMG="${DMG_NAME}.dmg"

# Check for code signing setup
DEVELOPER_ID=""
TEAM_ID=""

# Check if we have signing certificates
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    echo "🔐 Found Developer ID: $DEVELOPER_ID"

    # Extract team ID from certificate
    TEAM_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'[()]' '{print $2}')
    echo "👥 Team ID: $TEAM_ID"
else
    echo "⚠️  No Developer ID certificate found!"
    echo "📝 Creating unsigned app (will show security warnings on other machines)"
    echo ""
    echo "To fix this properly:"
    echo "1. Join Apple Developer Program ($99/year)"
    echo "2. Create Developer ID Application certificate in Xcode"
    echo "3. Re-run this script"
    echo ""
fi

# Clean up any existing files
rm -rf "$APP_DIR" "$TEMP_DMG" "$FINAL_DMG"

# Build the application if needed
if [ ! -f ".build/release/PRReviewLight" ]; then
    echo "📦 Building PR Review Light..."
    swift build -c release
fi

# Create app bundle structure
echo "📁 Creating app bundle..."
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/PRReviewLight "$MACOS_DIR/"

# Make binary executable
chmod +x "$MACOS_DIR/PRReviewLight"

# Create entitlements file for sandboxing (optional but good practice)
cat > "entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
EOF

# Sign the binary if we have a certificate
if [ ! -z "$DEVELOPER_ID" ]; then
    echo "🔐 Code signing binary..."
    codesign --force --deep --options runtime --entitlements entitlements.plist --sign "$DEVELOPER_ID" "$MACOS_DIR/PRReviewLight"

    # Verify the signature
    if codesign --verify --verbose "$MACOS_DIR/PRReviewLight" 2>/dev/null; then
        echo "✅ Binary signed successfully"
    else
        echo "❌ Binary signing failed"
        exit 1
    fi
else
    echo "⚠️  Skipping code signing (no certificate available)"
fi

# Create Info.plist with proper bundle identifier
BUNDLE_ID="com.prreviewlight.app"
if [ ! -z "$TEAM_ID" ]; then
    BUNDLE_ID="${TEAM_ID}.com.prreviewlight.app"
fi

cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PRReviewLight</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
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
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>github.com</key>
            <dict>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <false/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.2</string>
                <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
                <false/>
            </dict>
            <key>api.github.com</key>
            <dict>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <false/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.2</string>
                <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
                <false/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
EOF

# Sign the entire app bundle if we have a certificate
if [ ! -z "$DEVELOPER_ID" ]; then
    echo "🔐 Code signing app bundle..."
    codesign --force --deep --options runtime --sign "$DEVELOPER_ID" "$APP_DIR"

    # Verify the app bundle signature
    if codesign --verify --verbose "$APP_DIR" 2>/dev/null; then
        echo "✅ App bundle signed successfully"

        # Check if we can notarize (requires Apple ID credentials)
        echo "📤 Attempting notarization..."
        echo "ℹ️  If you haven't set up notarization credentials:"
        echo "   xcrun notarytool store-credentials --apple-id YOUR_APPLE_ID --team-id $TEAM_ID"
        echo ""

        # Create a zip for notarization
        ditto -c -k --keepParent "$APP_DIR" "${APP_DIR}.zip"

        # Note: Actual notarization requires configured credentials
        echo "⚠️  Notarization requires configured Apple ID credentials"
        echo "   Run: xcrun notarytool submit ${APP_DIR}.zip --keychain-profile \"notarytool-password\" --wait"
        echo "   Then: xcrun stapler staple \"$APP_DIR\""

        # Clean up zip
        rm -f "${APP_DIR}.zip"
    else
        echo "❌ App bundle signing failed"
        exit 1
    fi
fi

# Create a simple app icon (using SF Symbols)
# For a real distribution, you'd want a proper .icns file
echo "🎨 Setting up app bundle..."

# Calculate DMG size (app size + 10MB buffer)
APP_SIZE=$(du -sm "$APP_DIR" | cut -f1)
DMG_SIZE=$((APP_SIZE + 10))

echo "💿 Creating temporary DMG..."
hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "$APP_NAME" "$TEMP_DMG"

echo "📁 Mounting DMG..."
hdiutil attach "$TEMP_DMG" -mountpoint "/Volumes/$APP_NAME"

echo "📋 Copying app to DMG..."
cp -R "$APP_DIR" "/Volumes/$APP_NAME/"

# Create Applications symlink
echo "🔗 Creating Applications shortcut..."
ln -s /Applications "/Volumes/$APP_NAME/Applications"

# Create a README for first-time users
cat > "/Volumes/$APP_NAME/README - First Time Setup.txt" << 'EOF'
Welcome to PR Review Light! 🚀

INSTALLATION:
1. Drag "PR Review Light.app" to the Applications folder
2. Launch from Applications or Spotlight
3. The app appears in your menu bar

SETUP:
1. Click the menu bar icon → Settings
2. Get a GitHub Personal Access Token:
   • Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   • Generate new token with scopes: "repo" and "read:user"
3. Paste token in settings → Save → Test Connection
4. Done! You'll see:
   ✅ Green checkmark = No pending reviews
   ⚠️  Orange triangle (pulsing) = Reviews needed!

FEATURES:
• Auto-checks every 5 minutes for new review requests
• Click PR titles to open directly in browser
• Snooze specific reviews for 1 hour
• Secure token storage in macOS keychain

Never miss a code review again! 🎯
EOF

echo "🎨 Finalizing DMG appearance..."
# Set DMG window properties using AppleScript (with error handling)
osascript << 'EOF' || echo "⚠️  Window styling failed, but DMG is still functional"
tell application "Finder"
    tell disk "PR Review Light"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        try
            set position of item "PR Review Light.app" of container window to {150, 150}
            set position of item "Applications" of container window to {350, 150}
            set position of item "README - First Time Setup.txt" of container window to {250, 280}
        end try
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

echo "💿 Detaching temporary DMG..."
hdiutil detach "/Volumes/$APP_NAME"

echo "🗜️ Converting to final DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$FINAL_DMG"

# Sign the DMG if we have a certificate
if [ ! -z "$DEVELOPER_ID" ]; then
    echo "🔐 Code signing DMG..."
    codesign --force --sign "$DEVELOPER_ID" "$FINAL_DMG"

    if codesign --verify --verbose "$FINAL_DMG" 2>/dev/null; then
        echo "✅ DMG signed successfully"
    else
        echo "❌ DMG signing failed"
    fi
fi

# Clean up temporary files
rm -rf "$TEMP_DMG" "$APP_DIR" "entitlements.plist"

echo "✅ DMG created successfully: $FINAL_DMG"
echo ""

if [ -z "$DEVELOPER_ID" ]; then
    echo "⚠️  IMPORTANT: This DMG is unsigned!"
    echo ""
    echo "🚨 Your colleagues will see security warnings:"
    echo "1. 'App is damaged and can't be opened' or"
    echo "2. 'Cannot verify developer' dialogs"
    echo ""
    echo "🔧 Workarounds for colleagues:"
    echo "1. Right-click app → Open → Open (bypass Gatekeeper)"
    echo "2. Or run: sudo spctl --master-disable (disables Gatekeeper)"
    echo "3. Or run: xattr -dr com.apple.quarantine 'PR Review Light.app'"
    echo ""
    echo "🎯 Proper solution:"
    echo "1. Join Apple Developer Program (\$99/year)"
    echo "2. Get Developer ID certificate"
    echo "3. Re-run this script"
    echo ""
else
    echo "✅ This DMG is properly signed!"
    echo ""
    if security find-identity -v -p codesigning | grep -q "Developer ID Installer"; then
        echo "💡 You also have a Developer ID Installer certificate."
        echo "   Consider creating a .pkg installer for even better compatibility."
    fi
fi

echo "📤 To share with colleagues:"
echo "1. Share the $FINAL_DMG file"
echo "2. They double-click to mount"
echo "3. Drag PR Review Light.app to Applications"
echo "4. Launch and configure GitHub token"
echo ""
echo "🎉 macOS installer ready!"