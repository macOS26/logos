# Coincident Points Documentation Index

## Start Here

**New to coincident points?** Read these in order:

1. **COINCIDENT_POINTS_SUMMARY.md** - Executive overview (5 min read)
2. **COINCIDENT_POINTS_QUICK_REFERENCE.md** - Practical guide (10 min read)
3. **COINCIDENT_POINTS_DIAGRAMS.md** - Visual learning (5 min read)
4. **COINCIDENT_POINTS_RESEARCH.md** - Deep dive (30 min read)

## Quick Navigation

### I want to understand...

| Topic | Document | Section |
|-------|----------|---------|
| What are coincident points? | SUMMARY | Overview |
| How to find them | RESEARCH | Section 2 |
| How closed paths work | RESEARCH | Section 3 |
| Smooth point detection | QUICK_REF | Understanding Smooth Points |
| Ellipse handling | RESEARCH | Section 7 |
| Handle relationships | DIAGRAMS | Diagram 2, 5 |
| Selection behavior | SUMMARY | Selection Behavior |
| Handle updates | SUMMARY | Handle Update Behavior |
| Code patterns | QUICK_REF | Common Patterns |
| File locations | RESEARCH | Section 12 |
| Performance | SUMMARY | Performance Characteristics |

### I need to code...

| Task | Start With | File |
|------|------------|------|
| Find coincident points | QUICK_REF: Pattern 1 | CoincidentPointHandling.swift |
| Check if smooth | DIAGRAMS: Diagram 8 | DirectSelectionDrag.swift |
| Update linked handles | QUICK_REF: Pattern 4 | DirectSelectionDrag.swift |
| Select coincidents | SUMMARY: Selection | CoincidentPointHandling.swift |
| Edit ellipse | DIAGRAMS: Example 11 | DirectSelectionDrag.swift |
| Add tolerance | SUMMARY: Tolerance | Multiple files |
| Optimize | SUMMARY: Performance | CoincidentPointHandling.swift |

## Key Concepts

### 1. Coincident Point
A point at the same physical location as another point. Detected using Euclidean distance (default tolerance: 1.0 unit).

**File:** `findCoincidentPoints()` in CoincidentPointHandling.swift

### 2. Closed Path Endpoint
In a closed path, element 0 (Move) and the last element represent the same physical point. These are paired for selection and handle linking.

**File:** `findClosedPathEndpoints()` in CoincidentPointHandling.swift

### 3. Smooth Point
A point where incoming and outgoing handles form a straight line (180° apart). Detected using dot product of normalized vectors.

**Threshold:** dot < -0.98 (cos 170°, allowing 10° tolerance)

**Files:** `isPointSmooth()` and `isCoincidentPointSmooth()` in DirectSelectionDrag.swift

### 4. Handle Linking
When a user drags one boundary handle in a closed path, the opposite handle automatically updates to maintain tangency.

**File:** `calculateLinkedHandle()` in DirectSelectionDrag.swift

## Data Structures

### PointID
```swift
struct PointID {
    let shapeID: UUID          // Which shape
    let pathIndex: Int = 0     // Always 0 (single path per shape)
    let elementIndex: Int      // Which element in path
}
```

### HandleID
```swift
struct HandleID {
    let shapeID: UUID          // Which shape
    let pathIndex: Int = 0     // Always 0
    let elementIndex: Int      // Which element
    let handleType: HandleType // .control1 or .control2
}
```

### PathElement
```swift
enum PathElement {
    case move(to: VectorPoint)
    case line(to: VectorPoint)
    case curve(to: VectorPoint, control1: VectorPoint, control2: VectorPoint)
    case quadCurve(to: VectorPoint, control: VectorPoint)
    case close  // No parameters - implicit line to first point
}
```

## Tolerance Values

| Check | Value | Purpose |
|-------|-------|---------|
| Coincident finding | 1.0 units | Points at same location |
| Closed path endpoint | 0.1 units | First/last point match |
| Collapsed handle | 0.1 units | Handle at anchor? |
| Boundary check | 0.001 units | Very strict for boundaries |
| Collinearity | -0.98 dot | ~170° angle tolerance |

## Critical Functions

```
findCoincidentPoints(to:tolerance:)
├─ Searches across all visible shapes
├─ Returns Set<PointID> at same location
└─ Tolerance: 1.0 units

findClosedPathEndpoints(for:)
├─ Finds paired endpoints in closed paths
├─ Returns Set<PointID> with paired element
└─ Only if distance < 0.1 units

selectPointWithCoincidents(_:addToSelection:)
├─ Selects clicked point
├─ Adds coincident points
├─ Adds closed path opposite endpoint
└─ Shows all handles

isPointSmooth(handleID:)
├─ Checks for coincident smoothness first
├─ Falls back to regular smoothness check
└─ Returns: dot < -0.98

isCoincidentPointSmooth(elements:handleID:)
├─ Only for boundary handles
├─ Checks Element 1's c1 vs Last's c2
└─ Returns: dot < -0.98

checkFirstLastCoincidentForLive(elements:handleID:newPosition:)
├─ Called during handle drag
├─ Detects boundary handles
├─ Updates opposite handle
└─ Returns: true if updated

calculateLinkedHandle(anchorPoint:draggedHandle:originalOppositeHandle:)
├─ Maintains tangency
├─ Calculates opposite handle position
└─ Returns: CGPoint
```

## Common Code Patterns

### Pattern: Check for closed path
```swift
var lastIndex = elements.count - 1
if case .close = elements[lastIndex] {
    lastIndex -= 1
}
```

### Pattern: Get first point
```swift
if case .move(let to) = elements[0] {
    firstPoint = to
}
```

### Pattern: Get last point
```swift
if case .curve(let to, _, _) = elements[lastIndex] {
    lastPoint = to
}
```

### Pattern: Check collinearity
```swift
let vec1 = CGPoint(x: h1.x - anchor.x, y: h1.y - anchor.y)
let vec2 = CGPoint(x: h2.x - anchor.x, y: h2.y - anchor.y)
let len1 = sqrt(vec1.x*vec1.x + vec1.y*vec1.y)
let len2 = sqrt(vec2.x*vec2.x + vec2.y*vec2.y)
let norm1 = CGPoint(x: vec1.x/len1, y: vec1.y/len1)
let norm2 = CGPoint(x: vec2.x/len2, y: vec2.y/len2)
let dot = norm1.x*norm2.x + norm1.y*norm2.y
return dot < -0.98
```

## File Organization

```
logos inkpen.io/
├─ Views/DrawingCanvas/
│  ├─ DrawingCanvas+CoincidentPointHandling.swift (MAIN)
│  │  ├─ findCoincidentPoints()
│  │  ├─ findClosedPathEndpoints()
│  │  ├─ selectPointWithCoincidents()
│  │  └─ isSmoothCurvePoint()
│  │
│  ├─ DrawingCanvas+DirectSelectionDrag.swift (MAIN)
│  │  ├─ isPointSmooth()
│  │  ├─ isCoincidentPointSmooth()
│  │  ├─ checkFirstLastCoincidentForLive()
│  │  └─ calculateLinkedHandle()
│  │
│  └─ DrawingCanvas+PointHandleUtilities.swift
│     ├─ getPointPosition()
│     ├─ getHandlePosition()
│     ├─ movePointToAbsolutePosition()
│     └─ moveHandleToAbsolutePosition()
│
└─ Models/Handles/
   └─ PointAndHandleID.swift
      ├─ struct PointID
      ├─ struct HandleID
      └─ findCoincidentPoints(global)
```

## Testing Checklist

- [ ] Can select ellipse closing point (should auto-select opposite)
- [ ] Can drag ellipse handle (opposite should update)
- [ ] Can edit two coincident points together
- [ ] Handles maintain tangency during drag
- [ ] Can collapse/restore handles
- [ ] Selection shows all coincident points
- [ ] Performance is smooth with many shapes

## Glossary

| Term | Definition |
|------|-----------|
| Anchor point | The endpoint of a path element (the "to" parameter) |
| Control handle | A handle that controls the curve shape (control1, control2) |
| Coincident | At the same physical location |
| Collinear | On the same line (handles 180° apart) |
| Smooth point | A point where handles are collinear |
| Corner point | A point where handles are NOT collinear |
| Closure point | Where a closed path returns to its start |
| Boundary handle | A handle at the path closure boundary |

## Related Files (Reference)

- **VectorPath.swift** - Path element definitions
- **ProfessionalBezierMathematics.swift** - Bezier math utilities
- **PathOperations.swift** - Path operation utilities
- **VectorDocument.swift** - Document model
- **MetalComputeEngine.swift** - GPU acceleration (for future optimization)

## Version Info

- **Created:** 2025-11-04
- **Scope:** Coincident point research for Logos Inkpen
- **Files Analyzed:** 5 primary, 10+ supporting
- **Code Examples:** 20+
- **Status:** Complete and documented

