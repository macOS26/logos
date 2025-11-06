# Coincident Points Quick Reference Guide

## What Are Coincident Points?

Points at the **same physical location** in different path elements or at closed path boundaries.

### Types:
1. **Across Paths:** Two shapes with anchor points at the same location
2. **At Path Closure:** In a closed path, element 0 (Move) and the last element represent the same point

---

## Key Functions You'll Use

### 1. Find Coincident Points
```swift
let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: 1.0)
```
- Returns all points at same location (within tolerance)
- Uses Euclidean distance: `sqrt((x1-x2)^2 + (y1-y2)^2)`
- Default tolerance: 1.0 units

### 2. Find Closed Path Endpoints
```swift
let endpoints = findClosedPathEndpoints(for: pointID)
```
- Returns paired element (element 0 ↔ last element)
- Only works if path has `.close` element
- Only returns pairing if distance < 0.1 units

### 3. Select All Coincident Points
```swift
selectPointWithCoincidents(pointID)
```
- Selects the point
- + all coincident points
- + all closed path endpoints
- + shows all their handles

---

## Understanding Smooth Points

### Regular Points (Middle of Path)

A point is **smooth** when its incoming and outgoing handles form a **straight line** (180° apart):

```
Incoming Handle ←--- Anchor Point ---→ Outgoing Handle
```

**Check:**
```swift
let dot = normalize(v1) · normalize(v2)
return dot < -0.98  // cos(170°) = -0.98
```

### Closed Path Points (At Boundaries)

For element 0 ↔ last element coincidence, smoothness is determined by:
```
Last Element's Incoming ←--- Shared Point ---→ First Element's Outgoing
```

Specifically:
- Last element's `control2` (incoming)
- Element 1's `control1` (outgoing)

Must be collinear with the shared anchor point.

---

## Path Element Structure

### Closed Path Example:
```
Element 0: .move(to: point0)         ← First point, no handles
Element 1: .curve(...control1,...)   ← control1 = outgoing from point0
Element 2: .curve(...control1,...)   ← 
...
ElementN: .curve(...control2,...)    ← control2 = incoming to point0
ElementN+1: .close                    ← Implicit line back to element 0
```

### Critical Handle Positions:
- Element 1's `.control1` = outgoing from closure point
- Last curve's `.control2` = incoming to closure point
- **These must be collinear for smooth closure**

---

## Common Patterns

### Pattern: Check if Path is Closed
```swift
var lastElementIndex = elements.count - 1
if case .close = elements[lastElementIndex] {
    lastElementIndex -= 1  // Get last real point
}
```

### Pattern: Get Closure Point Coordinates
```swift
var firstPoint, lastPoint: VectorPoint?

if case .move(let to) = elements[0] {
    firstPoint = to
}
if case .curve(let to, _, _) = elements[lastElementIndex] {
    lastPoint = to
}
```

### Pattern: Check Handle Collinearity
```swift
let vec1 = CGPoint(x: h1.x - anchor.x, y: h1.y - anchor.y)
let vec2 = CGPoint(x: h2.x - anchor.x, y: h2.y - anchor.y)

// Normalize
let len1 = sqrt(vec1.x*vec1.x + vec1.y*vec1.y)
let len2 = sqrt(vec2.x*vec2.x + vec2.y*vec2.y)
let norm1 = CGPoint(x: vec1.x/len1, y: vec1.y/len1)
let norm2 = CGPoint(x: vec2.x/len2, y: vec2.y/len2)

// Check alignment
let dot = norm1.x*norm2.x + norm1.y*norm2.y
let isSmooth = dot < -0.98  // ~170° tolerance
```

### Pattern: Link Opposite Handles
```swift
let linkedHandle = calculateLinkedHandle(
    anchorPoint: anchor,
    draggedHandle: newPosition,
    originalOppositeHandle: original
)
// This maintains symmetry when dragging one handle
```

---

## Important Thresholds

| Check | Threshold | Meaning |
|-------|-----------|---------|
| Collapsed Handle | 0.1 units | Is handle at anchor? |
| Coincident Point | 1.0 units | Are two points the same? |
| Path Closure | 0.1 units | Do first/last points match? |
| Handle Collinearity | dot < -0.98 | ~170° angle tolerance |
| Boundary Coincidence | 0.001 units | Super strict for first/last |

---

## Handle Anatomy

```
PathElement.curve(
    to: VectorPoint,        ← Anchor point location
    control1: VectorPoint,  ← Outgoing handle (from previous point)
    control2: VectorPoint   ← Incoming handle (to this point)
)
```

**For Element at Index i:**
- `control1` = outgoing from anchor at element i-1
- `control2` = incoming to anchor at element i

---

## Ellipse/Circle Handling

Ellipses are **closed paths with 4 curves** (+ .close):
```
Element 0: .move(top)
Element 1: .curve(right_quarter, control1=outgoing from top)
Element 2: .curve(bottom_quarter)
Element 3: .curve(left_quarter)
Element 4: .curve(back to top, control2=incoming to top)
Element 5: .close
```

**For smooth ellipse:**
- Element 1's `control1` and Element 4's `control2` must be collinear with top point
- Same logic applies as any closed path

---

## When to Update Handles

**Automatic update happens when:**
1. Selecting a closed path endpoint → opposite endpoint also selected
2. Dragging element 1's `control1` → automatically update last element's `control2`
3. Dragging last element's `control2` → automatically update element 1's `control1`

**Via:** `checkFirstLastCoincidentForLive()` and `calculateLinkedHandle()`

---

## File Quick Lookup

| Need to... | File | Function |
|-----------|------|----------|
| Find coincident points | CoincidentPointHandling.swift | `findCoincidentPoints()` |
| Check smooth closure | DirectSelectionDrag.swift | `isCoincidentPointSmooth()` |
| Update linked handles | DirectSelectionDrag.swift | `calculateLinkedHandle()` |
| Select all coincidents | CoincidentPointHandling.swift | `selectPointWithCoincidents()` |
| Get point position | PointHandleUtilities.swift | `getPointPosition()` |
| Get handle position | PointHandleUtilities.swift | `getHandlePosition()` |

