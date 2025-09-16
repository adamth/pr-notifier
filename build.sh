#!/bin/bash

# Build script for PR Review Light

echo "Building PR Review Light..."

# Build the application
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "To run the application:"
    echo "./.build/release/PRReviewLight"
    echo ""
    echo "Make sure to set your GitHub token first:"
    echo "export GITHUB_TOKEN=\"your_token_here\""
else
    echo "❌ Build failed!"
    exit 1
fi