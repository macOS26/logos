#!/bin/bash

# Fix Metal Framework Libraries Path Issue
# This script sets the correct Metal library paths for your SwiftUI app

export METAL_LIBRARY_PATH="/System/Library/PrivateFrameworks/RenderBox.framework/Versions/A/Resources"
export METAL_DEVICE_WRAPPER_TYPE="1"

# Optional: Set additional Metal environment variables for debugging
export METAL_DEBUG_ERROR_MODE="1"
export METAL_SHADER_VALIDATION="1"

echo "Metal environment variables configured:"
echo "METAL_LIBRARY_PATH=$METAL_LIBRARY_PATH"
echo "METAL_DEVICE_WRAPPER_TYPE=$METAL_DEVICE_WRAPPER_TYPE"

# Run your app with the correct Metal paths
if [ -f "build/Release/logos inkpen.io.app/Contents/MacOS/logos inkpen.io" ]; then
    echo "Starting logos inkpen.io with Metal fixes..."
    "./build/Release/logos inkpen.io.app/Contents/MacOS/logos inkpen.io"
else
    echo "Please build your app first with: xcodebuild -project 'logos inkpen.io.xcodeproj' -configuration Release build"
fi
