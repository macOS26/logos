# Project: logos inkpen.io - SwiftUI Refactoring Guidelines

## Critical Rules
- **ONE FILE AT A TIME**: Only refactor ONE file before building and committing
- **ALWAYS BUILD**: Run `xcf build` after EVERY file change
- **COMMIT AFTER BUILD**: If build succeeds, commit immediately with git
- **NO BREAKS**: Continue working until explicitly told to stop

## Refactoring Standards
1. Remove duplicate imports (especially duplicate `import SwiftUI`)
2. Extract repeated styles into ViewModifier structs
3. Create reusable subviews for complex repeated patterns
4. Use extension methods for easy style application
5. Focus on low-risk, single-file changes

## Common Style Patterns to Extract
- `.font(.caption)` + `.foregroundColor(.secondary)` → Label styles
- `.font(.system(...))` + `.foregroundColor(...)` → Text styles
- Repeated picker configurations → Picker styles
- Repeated button styles → Button styles
- Slider + TextField combinations → Control components

## Build and Commit Process
```bash
1. Make changes to ONE file
2. xcf build
3. If successful: git add [file] && git commit -m "message"
4. Move to next file
```

## Current Task
Systematically refactoring SwiftUI view files to extract common styles and reduce code duplication.