#!/bin/bash

echo "🧪 Testing PR Review Light Notifications"
echo "========================================"

# Kill any existing instances
pkill -f PRReviewLight || echo "No existing instances found"
sleep 1

# Start the app
echo "🚀 Starting PR Review Light..."
./.build/release/PRReviewLight &
APP_PID=$!

echo "⏳ Waiting for app to initialize..."
sleep 3

echo "📱 App should now be running in the menu bar"
echo ""
echo "🔔 To test notifications:"
echo "1. Click the menu bar icon"
echo "2. Go to Settings"
echo "3. Click 'Test Notification' button"
echo "4. You should see a test notification appear"
echo ""
echo "📋 To test with real data:"
echo "1. Add your GitHub token in Settings"
echo "2. Click 'Test Connection'"
echo "3. Wait for the app to find review requests"
echo "4. New PRs will trigger notifications"
echo ""
echo "🛑 To stop the app:"
echo "   kill $APP_PID"
echo ""
echo "✅ App is running with PID: $APP_PID"