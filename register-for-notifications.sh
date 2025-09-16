#!/bin/bash

echo "🔔 PR Review Light - Notification Registration Helper"
echo "=================================================="
echo ""

echo "This script helps register PR Review Light with macOS notification system."
echo ""

# Step 1: Kill any existing instances
echo "1️⃣ Stopping any running instances..."
pkill -f PRReviewLight || echo "   No running instances found"
sleep 2

# Step 2: Start the app from bundle
echo "2️⃣ Starting PR Review Light from app bundle..."
if [ -d "PRReviewLight.app" ]; then
    open PRReviewLight.app
    echo "   ✅ App started"
else
    echo "   ❌ PRReviewLight.app not found. Run ./create-dmg.sh first."
    exit 1
fi

# Step 3: Wait for startup
echo "3️⃣ Waiting for app initialization..."
sleep 3

# Step 4: Instructions
echo "4️⃣ Manual steps to complete registration:"
echo ""
echo "   a) Click the PR Review Light icon in your menu bar"
echo "   b) Select 'Settings'"
echo "   c) Click 'Test Notification' button"
echo "   d) When prompted, click 'Allow' for notifications"
echo ""
echo "5️⃣ If notifications are still denied:"
echo ""
echo "   a) Quit PR Review Light completely (Cmd+Q from menu)"
echo "   b) Run this script again"
echo "   c) Try the test notification 2-3 times"
echo "   d) Check System Settings > Notifications for 'PR Review Light'"
echo ""
echo "📱 Why this happens:"
echo "   Unsigned macOS apps need to 'prove themselves' to the system"
echo "   before appearing in notification settings. This usually takes"
echo "   2-3 attempts with restarts."
echo ""
echo "🎉 Once registered, notifications will work reliably!"
echo ""
echo "Current app PID: $(pgrep -f PRReviewLight || echo 'Not running')"