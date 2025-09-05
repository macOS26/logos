# Unified System Migration Plan
## Migrating from Legacy Arrays to Unified Object System

### Executive Summary
This plan details the systematic migration from `selectedShapeIDs`/`selectedTextIDs` to the unified `selectedObjectIDs` system. The migration will be done in micro-steps, with each step building, testing, and committing before proceeding.

### Current State Analysis
- **110 total legacy references** across the codebase
- **26 syncSelectionArrays() calls** maintaining compatibility
- **Risk Level**: LOW to MEDIUM (unified system already functional)
- **Estimated Time**: 15-20 hours total, done in 30-minute micro-steps

---

## Phase 1: Low-Risk Replacements (2-3 hours)
*Simple boolean checks and UI displays that don't modify state*

### Micro-Step 1.1: StatusBar isEmpty Checks
**File**: `Views/MainView/StatusBar.swift`
**Change**: Replace `selectedShapeIDs.isEmpty && selectedTextIDs.isEmpty` with `selectedObjectIDs.isEmpty`
**Test**: Verify status bar shows correct selection state
**Build**: `xcf build`
**Commit**: "refactor: Replace StatusBar isEmpty checks with unified system"

### Micro-Step 1.2: DrawingCanvas isEmpty Checks  
**File**: `Views/DrawingCanvas/DrawingCanvas+SafeMetalIntegration.swift`
**Changes**: 
- Line 66: `!selectedShapeIDs.isEmpty` → `!selectedObjectIDs.isEmpty`
- Line 197: `!selectedShapeIDs.isEmpty` → `hasSelectedShapes()`
**Test**: Verify Metal rendering still works with selections
**Build**: `xcf build`
**Commit**: "refactor: Update DrawingCanvas Metal integration for unified system"

### Micro-Step 1.3: DrawingCanvas Unified Gestures
**File**: `Views/DrawingCanvas/DrawingCanvas+UnifiedGestures.swift`
**Changes**:
- Line 359: Combined isEmpty check → `selectedObjectIDs.isEmpty`
- Line 364: OR isEmpty check → `!selectedObjectIDs.isEmpty`
**Test**: Verify gesture handling works
**Build**: `xcf build`
**Commit**: "refactor: Simplify DrawingCanvas gesture selection checks"

### Micro-Step 1.4: Simple Test File Updates
**Files**: All test files
**Change**: Update test assertions to use unified system
**Test**: Run full test suite
**Build**: `swift test`
**Commit**: "test: Update test files for unified selection system"

---

## Phase 2: Helper Method Introduction (1-2 hours)
*Add convenience methods to reduce code duplication*

### Micro-Step 2.1: Add Selection Query Helpers
**File**: `Utilities/Vector/VectorDocument+UnifiedObjectManagement.swift`
**Add**:
```swift
extension VectorDocument {
    var hasSelection: Bool { !selectedObjectIDs.isEmpty }
    var hasShapeSelection: Bool { 
        selectedObjectIDs.contains { id in
            unifiedObjects.first { $0.id == id }?.isShape ?? false
        }
    }
    var hasTextSelection: Bool {
        selectedObjectIDs.contains { id in
            textObjects.contains { $0.id == id }
        }
    }
    var selectionCount: Int { selectedObjectIDs.count }
}
```
**Test**: Verify helpers work correctly
**Build**: `xcf build`
**Commit**: "feat: Add unified selection query helper methods"

### Micro-Step 2.2: Replace Simple Checks with Helpers
**Files**: Multiple
**Changes**: Replace isEmpty checks with new helpers
**Test**: Run tests
**Build**: `xcf build`  
**Commit**: "refactor: Use selection helper methods throughout codebase"

---

## Phase 3: DocumentState Command Updates (2-3 hours)
*Update menu command logic to use unified system*

### Micro-Step 3.1: Duplicate Command
**File**: `App/DocumentState.swift`
**Change**:
```swift
// OLD:
if !document.selectedShapeIDs.isEmpty {
    document.duplicateSelectedShapes()
} else if !document.selectedTextIDs.isEmpty {
    document.duplicateSelectedTexts()
}

// NEW:
if document.hasSelection {
    document.duplicateSelectedObjects() // New unified method
}
```
**Test**: Test duplicate command with shapes and text
**Build**: `xcf build`
**Commit**: "refactor: Update duplicate command for unified system"

### Micro-Step 3.2: Clean Duplicate Points Command
**File**: `App/DocumentState.swift`
**Change**: Use `hasShapeSelection` helper
**Test**: Verify path cleanup works
**Build**: `xcf build`
**Commit**: "refactor: Update path cleanup for unified selection"

### Micro-Step 3.3: Lock/Hide Commands
**File**: `Utilities/Vector/VectorDocument+ObjectVisibility.swift`
**Change**: Replace dual isEmpty checks with `hasSelection`
**Test**: Test lock/hide operations
**Build**: `xcf build`
**Commit**: "refactor: Simplify lock/hide commands with unified system"

---

## Phase 4: Path Operations Migration (2-3 hours)
*Update path manipulation code*

### Micro-Step 4.1: PathOperations Selected Shapes
**File**: `Utilities/Vector/PathOperations.swift`
**Change**: Replace `selectedShapeIDs` iteration with `getSelectedShapes()`
**Test**: Test path operations
**Build**: `xcf build`
**Commit**: "refactor: Update PathOperations for unified selection"

### Micro-Step 4.2: Offset Path Operations
**File**: `Views/RightPanel/ProfessionalOffsetPathSection.swift`
**Changes**: Use `hasShapeSelection` helper
**Test**: Test offset path UI
**Build**: `xcf build`
**Commit**: "refactor: Update offset path for unified system"

---

## Phase 5: FontPanel Migration (4-5 hours)
*Most complex component with 11 text selection dependencies*

### Micro-Step 5.1: Add Text Selection Helper
**File**: `Utilities/Vector/VectorDocument+UnifiedObjectManagement.swift`
**Add**:
```swift
var selectedTextObjects: [VectorText] {
    textObjects.filter { selectedObjectIDs.contains($0.id) }
}
var firstSelectedText: VectorText? {
    selectedTextObjects.first
}
```
**Test**: Verify helpers work
**Build**: `xcf build`
**Commit**: "feat: Add text selection helpers for FontPanel"

### Micro-Step 5.2: FontPanel Property Observers
**File**: `Views/RightPanel/FontPanel.swift`
**Change**: Replace `selectedTextIDs` observers with unified observers
**Test**: Test font panel updates
**Build**: `xcf build`
**Commit**: "refactor: Update FontPanel observers for unified system"

### Micro-Step 5.3: FontPanel Text Modifications
**File**: `Views/RightPanel/FontPanel.swift`
**Change**: Update all text property modifications to use helpers
**Test**: Test all font operations
**Build**: `xcf build`
**Commit**: "refactor: Complete FontPanel migration to unified system"

---

## Phase 6: Remove syncSelectionArrays (2-3 hours)
*Remove compatibility layer*

### Micro-Step 6.1: Remove syncSelectionArrays Calls
**Files**: All files with syncSelectionArrays
**Change**: Delete all `syncSelectionArrays()` calls
**Test**: Run full test suite
**Build**: `xcf build`
**Commit**: "refactor: Remove syncSelectionArrays calls"

### Micro-Step 6.2: Update Selection Setters
**File**: `Utilities/Vector/VectorDocument+UnifiedObjectManagement.swift`
**Change**: Make legacy arrays computed properties that derive from unified system
```swift
var selectedShapeIDs: Set<UUID> {
    get {
        Set(unifiedObjects
            .filter { selectedObjectIDs.contains($0.id) && $0.isShape }
            .map { $0.id })
    }
    set {
        // Update unified system when legacy array is set
        selectedObjectIDs = selectedObjectIDs.union(newValue)
    }
}
```
**Test**: Verify backward compatibility
**Build**: `xcf build`
**Commit**: "refactor: Make legacy arrays computed from unified system"

---

## Phase 7: Final Cleanup (1-2 hours)
*Remove legacy code and update documentation*

### Micro-Step 7.1: Remove Legacy Array Storage
**File**: `Utilities/Vector/VectorDocument.swift`
**Change**: Remove `@Published` from legacy arrays, keep computed properties
**Test**: Full test suite
**Build**: `xcf build`
**Commit**: "refactor: Remove legacy array storage, keep computed properties"

### Micro-Step 7.2: Update File Encoding/Decoding
**File**: `Utilities/Vector/VectorDocument.swift`
**Change**: Make legacy arrays encode/decode through unified system
**Test**: Test file save/load
**Build**: `xcf build`
**Commit**: "refactor: Update file format for unified selection"

### Micro-Step 7.3: Documentation Update
**Files**: README.md, inline comments
**Change**: Document unified system as primary selection mechanism
**Build**: `xcf build`
**Commit**: "docs: Update documentation for unified selection system"

---

## Rollback Strategy

Each micro-step is atomic and can be reverted with:
```bash
git revert HEAD
```

If issues arise mid-phase, the compatibility layer (syncSelectionArrays) can be temporarily restored until the issue is fixed.

---

## Success Metrics

1. **All tests pass** after each micro-step
2. **No runtime crashes** during normal usage
3. **Performance improvement** in selection operations
4. **Reduced code complexity** (110 references → ~30 references)
5. **Backward compatibility** maintained for file format

---

## Risk Mitigation

1. **Keep computed properties** for legacy arrays initially
2. **Test each micro-step** thoroughly before committing
3. **Monitor performance** with large documents
4. **Keep syncSelectionArrays** available but deprecated
5. **Run full app after each phase** to catch integration issues

---

## Timeline

- **Phase 1**: Day 1, Morning (2-3 hours)
- **Phase 2**: Day 1, Afternoon (1-2 hours)
- **Phase 3**: Day 2, Morning (2-3 hours)
- **Phase 4**: Day 2, Afternoon (2-3 hours)
- **Phase 5**: Day 3 (4-5 hours)
- **Phase 6**: Day 4, Morning (2-3 hours)
- **Phase 7**: Day 4, Afternoon (1-2 hours)

Total: 15-20 hours over 4 days, done in micro-steps with commits after each successful change.