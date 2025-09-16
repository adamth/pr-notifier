#!/bin/bash

# Setup script for proper macOS code signing
# This helps configure Developer ID certificates for distribution

echo "🔐 macOS Code Signing Setup"
echo "=========================="
echo ""

# Check current certificate status
echo "📋 Checking current certificates..."
CERTS=$(security find-identity -v -p codesigning)

if echo "$CERTS" | grep -q "Developer ID Application"; then
    echo "✅ Found Developer ID Application certificate:"
    echo "$CERTS" | grep "Developer ID Application"
    echo ""
else
    echo "❌ No Developer ID Application certificate found"
    echo ""
    echo "🎯 To get proper code signing certificates:"
    echo ""
    echo "1. Join Apple Developer Program:"
    echo "   → https://developer.apple.com/programs/"
    echo "   → Cost: $99/year"
    echo ""
    echo "2. Create certificates:"
    echo "   Option A - Xcode (Recommended):"
    echo "   → Open Xcode"
    echo "   → Preferences → Accounts → Add Apple ID"
    echo "   → Select your team → Manage Certificates"
    echo "   → + → Developer ID Application"
    echo ""
    echo "   Option B - Developer Portal:"
    echo "   → https://developer.apple.com/account/resources/certificates/"
    echo "   → + → Developer ID Application"
    echo "   → Download and install .cer file"
    echo ""
    echo "3. Set up notarization (for Gatekeeper):"
    echo "   → Generate app-specific password:"
    echo "     https://appleid.apple.com/account/manage → Security → App-Specific Passwords"
    echo ""
    echo "   → Store credentials:"
    echo "     xcrun notarytool store-credentials --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID"
    echo ""
fi

# Check for notarization setup
echo "📤 Checking notarization setup..."
if xcrun notarytool history 2>/dev/null | head -1 | grep -q "Successfully received submission history"; then
    echo "✅ Notarization credentials configured"
else
    echo "⚠️  Notarization not configured"
    echo "   This is needed to avoid 'damaged app' warnings on other machines"
fi

echo ""
echo "🔍 Alternative solutions for unsigned apps:"
echo ""
echo "For YOUR COLLEAGUES to bypass security warnings:"
echo "1. Right-click app → Open → Open (one-time bypass)"
echo "2. System Preferences → Security & Privacy → Allow anyway"
echo "3. Terminal command: xattr -dr com.apple.quarantine 'PR Review Light.app'"
echo ""
echo "⚠️  These are workarounds. Proper signing is the best solution."
echo ""

# Test current setup
echo "🧪 Testing current setup..."
if [ -f "PRReviewLight.app/Contents/MacOS/PRReviewLight" ]; then
    echo "Checking existing app signature..."
    if codesign --verify --verbose "PRReviewLight.app" 2>/dev/null; then
        echo "✅ App is signed"
        codesign -dv "PRReviewLight.app" 2>&1 | grep "Authority="
    else
        echo "❌ App is not signed"
    fi
else
    echo "ℹ️  No app bundle found. Run ./create-dmg.sh first."
fi

echo ""
echo "🚀 Next steps:"
if echo "$CERTS" | grep -q "Developer ID Application"; then
    echo "✅ You're ready! Run ./create-dmg.sh to create a signed DMG"
else
    echo "1. Get Apple Developer Program membership"
    echo "2. Create Developer ID Application certificate"
    echo "3. Run ./create-dmg.sh"
    echo "4. (Optional) Set up notarization for best experience"
fi