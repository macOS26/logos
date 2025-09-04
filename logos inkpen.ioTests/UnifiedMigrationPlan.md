# SINGLE SOURCE OF TRUTH MIGRATION PLAN

## CURRENT STATE
- ✅ All violations fixed - everything uses unified helpers for WRITES
- ❌ 343 legacy READ accesses to layers[].shapes 
- ❌ 87 legacy READ accesses to textObjects[]

## END GAME: unifiedObjects ONLY

### Phase 1: Unified Query Methods (READ operations)
Add these methods to replace legacy array reads:

```swift
// Replace layers[].shapes reads
func getShapesInLayer(_ layerIndex: Int) -> [VectorShape]
func getShapeById(_ id: UUID) -> VectorShape?
func getAllShapes() -> [VectorShape]
func getVisibleShapes() -> [VectorShape]

// Replace textObjects[] reads  
func getAllTextObjects() -> [VectorText]
func getTextById(_ id: UUID) -> VectorText?
func getVisibleTextObjects() -> [VectorText]

// Unified queries
func getAllObjectsInLayer(_ layerIndex: Int) -> [VectorObject]
func getObjectById(_ id: UUID) -> VectorObject?
```

### Phase 2: Replace All Read Operations
- Convert 343 layers[].shapes reads to unified queries
- Convert 87 textObjects[] reads to unified queries
- Update all iteration loops to use unified system

### Phase 3: Remove Legacy Arrays
Once all reads go through unified system:
- Remove layers[].shapes arrays
- Remove textObjects[] array  
- Keep only unifiedObjects array
- Remove all sync methods

### Phase 4: Simplify Helper Methods
- Remove dual-system maintenance from all helpers
- Direct manipulation of unifiedObjects only
- Clean up all temporary bridge code

## TIMELINE
- Phase 1: 2-3 commits (add query methods)
- Phase 2: 5-10 commits (migrate reads by file category)
- Phase 3: 1 commit (remove legacy arrays) 
- Phase 4: 1-2 commits (cleanup)

## RISK MITIGATION
- Maintain comprehensive tests throughout
- Migrate in small, testable chunks
- Keep builds working at each step
- Preserve all functionality during migration