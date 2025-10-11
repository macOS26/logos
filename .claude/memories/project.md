# Project: logos inkpen.io

## Overview
This is a SwiftUI-based vector graphics application for macOS that provides professional drawing and design tools.

## Key Technologies
- SwiftUI for UI
- Metal for GPU acceleration
- CoreGraphics for path operations
- PDF/SVG import/export support

## Project Structure
- `/Views/` - SwiftUI view components
- `/Models/` - Data models and business logic
- `/Utilities/` - Helper functions and utilities
- `/App/` - Application lifecycle and configuration

## Recent Work
- Extracting common styles from SwiftUI views to reduce code duplication
- Creating reusable ViewModifiers and style components
- Improving code maintainability through refactoring

## Important Guidelines
- Work on ONE file at a time
- Always build with `xcf build` after changes
- Commit each file separately after successful build
- Focus on low-risk refactoring changes
- Extract repeated styles into ViewModifiers or reusable components

## Common Patterns
- Use ViewModifier for repeated styles
- Create extension methods for easy style application
- Extract reusable subviews for complex repeated UI patterns
- Remove duplicate imports