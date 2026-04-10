# LayersPanel Performance Optimization Plan

## Problems Identified

1. **Non-lazy rendering**: Using `ForEach` without `LazyVStack` renders ALL items even off-screen
2. **Expensive computed properties**: `layerObjects` computed on every render with `.reversed()` + `.compactMap()`
3. **Over-subscribing**: Watching entire `snapshot.layers` and `snapshot.objects` causes re-render on ANY change
4. **Heavy overlay system**: Duplicate `ForEach` loops for eye/lock drag targets

## Solutions (Priority Order)

### ✅ **Priority 1: Use LazyVStack** (Biggest Impact)
- Replace `VStack` with `LazyVStack` in `layersScrollContent`
- Only renders visible rows
- **Expected speedup**: 5-10x for large layer counts

### ✅ **Priority 2: Remove Global Subscriptions**
- Remove lines 181-185 that subscribe to entire snapshot
- Use `@ObservedObject` on document, rely on `viewState.layerUpdateTriggers`
- Only re-render when specific layer changes
- **Expected speedup**: 2-3x

### ✅ **Priority 3: Cache layerObjects**
- Make `layerObjects` an `@State` variable
- Update only when layer.objectIDs changes
- Avoid repeated `.reversed()` + `.compactMap()`
- **Expected speedup**: 1.5-2x

### ⚠️ **Priority 4: Simplify Overlay System** (Optional)
- Consider removing drag-to-toggle for eye/lock
- Or make overlays lazy with `LazyVStack`
- **Expected speedup**: 1.2-1.5x

### ⚠️ **Priority 5: Use Equatable for Rows** (Optional)
- Make ProfessionalLayerRow and ObjectRow conform to Equatable
- Prevents unnecessary re-renders
- **Expected speedup**: 1.1-1.3x

## Implementation Order

1. Add LazyVStack (5 min fix, huge impact)
2. Remove global subscriptions (10 min fix, big impact)
3. Cache layerObjects (15 min fix, medium impact)
4. Test performance with real documents
5. If still slow, implement Priority 4-5

## Code Changes Needed

### File: LayersPanel.swift
- Line 342-349: Wrap in LazyVStack
- Line 181-185: Remove or comment out subscriptions
- Line 346: Add `.id()` modifier for stable identity

### File: ProfessionalLayerRow.swift
- Line 23-28: Convert to @State with onChange
- Line 259: Ensure ForEach uses stable IDs
