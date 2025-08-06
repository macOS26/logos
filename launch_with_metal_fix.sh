#!/bin/bash

# Launch Script for logos inkpen.io with Metal Framework Fix
# This script ensures Metal can find its libraries properly

echo "🔧 Configuring Metal Framework Environment..."

# Set the correct Metal library path
export METAL_LIBRARY_PATH="/System/Library/PrivateFrameworks/RenderBox.framework/Versions/A/Resources"

# Verify Metal libraries exist
if [ -f "$METAL_LIBRARY_PATH/default.metallib" ]; then
    echo "✅ Metal libraries found at: $METAL_LIBRARY_PATH"
else
    echo "❌ Metal libraries not found. Please check your macOS installation."
    exit 1
fi

# Check if the app is built
APP_PATH="./build/Release/logos inkpen.io.app"
if [ ! -d "$APP_PATH" ]; then
    echo "📦 Building the app first..."
    xcodebuild -project "logos inkpen.io.xcodeproj" -configuration Release build
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Please check the build errors."
        exit 1
    fi
fi

echo "🚀 Launching logos inkpen.io with Metal fixes..."

# Launch the app with proper environment
METAL_LIBRARY_PATH="$METAL_LIBRARY_PATH" open "$APP_PATH"

echo "✅ App launched successfully!"
