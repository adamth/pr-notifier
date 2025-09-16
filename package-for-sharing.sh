#!/bin/bash

# Package PR Review Light for sharing with colleagues

echo "📦 Creating PR Review Light distribution package..."

# Clean up any existing build artifacts
rm -rf .build PRReviewLight.app *.zip

# Create distribution directory
rm -rf dist
mkdir -p dist/PRReviewLight

# Copy only the source files we need (excluding dist directory)
cp *.swift dist/PRReviewLight/
cp *.sh dist/PRReviewLight/
cp *.md dist/PRReviewLight/
cp Package.swift dist/PRReviewLight/

cd dist/PRReviewLight

# Clean up development files
rm -rf .build
rm -f pr-review-light.log
rm -f test.swift simple-test.swift

echo "✅ Created clean source distribution"
echo ""
echo "📤 To share with colleagues:"
echo "1. Zip the 'dist/PRReviewLight' folder"
echo "2. Share the zip file"
echo "3. They extract and run: cd PRReviewLight && ./install.sh"
echo ""
echo "📋 Or create a pre-built app bundle:"
echo "   cd dist/PRReviewLight && ./install.sh"
echo "   Then share the PRReviewLight.app bundle"