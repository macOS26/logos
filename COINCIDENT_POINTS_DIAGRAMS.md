# Coincident Points - Visual Diagrams & Examples

## 1. Regular Closed Path Structure

```
CLOSED PATH (with 4 curve elements):

        Element 1
    (Curve 1)
   ↙         ↘
  /     c1    \
 /       ↓      \
Element 0 ←→ Element 4
(Move)        (Curve 4)
 \       ↑      /
  \     c2    /
   ↘         ↙
   Element 2,3,4
   (Curve 2,3,4)

Key Points:
- Element 0 (Move): First point, NO handles
- Element 1 (Curve): Has control1 (outgoing from Element 0) and control2
- Element N (Last Curve): Has control1 and control2 (incoming to Element 0)
- Element N+1: .close (implicit line back to Element 0)
```

---

## 2. Handle Pairing at Closure

```
CLOSED PATH SMOOTHNESS CHECK:

For a smooth closure:
Element 1's outgoing handle ←→ Shared Anchor Point ←→ Last Element's incoming handle

Visually:

Last Element's c2      Element 0/N Anchor        Element 1's c1
(incoming handle) ←────────────────────────→ (outgoing handle)

Must form straight line (180° apart, dot product < -0.98)

CODE CHECK:
let vec1 = (handle1.x - anchor.x, handle1.y - anchor.y)
let vec2 = (handle2.x - anchor.x, handle2.y - anchor.y)
let dot = normalize(vec1) · normalize(vec2)
isSmooth = dot < -0.98  // cos(170°)
```

---

## 3. Ellipse as Closed Path

```
ELLIPSE STRUCTURE (4 curves + close):

              Element 1
            /   curve   \
           /             \
     Element 0 -------- Element 4
        (Move)          (Curve)
     (top point)
      \             /
       \ Element 2,3/
        \   curves /

Detailed:
Element 0: .move(x: 250, y: 100)           ← Top point
Element 1: .curve(                         ← Right quarter
            to: (350, 200),                  
            control1: (350, 100),  ← OUTGOING from top
            control2: (400, 150)
           )
Element 2: .curve(...) ← Bottom quarter
Element 3: .curve(...) ← Left quarter
Element 4: .curve(                         ← Back to top
            to: (250, 100),
            control1: (100, 150),
            control2: (150, 100)  ← INCOMING to top
           )
Element 5: .close

FOR SMOOTH ELLIPSE:
Element 1's c1 (350, 100) must be collinear with:
Element 4's c2 (150, 100) through:
Anchor point (250, 100)
```

---

## 4. Coincident Point Across Paths

```
TWO SHAPES WITH COINCIDENT POINTS:

Shape 1           Shape 2
 ╱─╲              ╱─╲
│ A │ ←→ Coincident │ B │
 ╲─╱   (same loc)   ╲─╱

When user selects point A:
1. findCoincidentPoints() detects point B
2. Both A and B are selected
3. Both A and B handles become visible

Distance Check:
distance(A, B) = sqrt((A.x - B.x)² + (A.y - B.y)²)
if distance <= tolerance (1.0 units), then coincident
```

---

## 5. Handle Linking Behavior

```
HANDLE LINKING IN CLOSED PATH:

User drags Element 1's control1:

BEFORE:              AFTER:
E1.c1 → *           E1.c1 → *'
          \                   \
           ↘ anchor           ↘ anchor
           /                   /
E4.c2 ← *           E4.c2 ← *'
         (auto-updated)

calculateLinkedHandle() ensures:
- E4.c2 maintains tangency with E1.c1
- Both form straight line through anchor
- Symmetry is preserved for smooth curves
```

---

## 6. Selection Cascade

```
USER SELECTS CLOSED PATH ENDPOINT:

Click on Element 0 (or last element)
           ↓
selectPointWithCoincidents() called
           ↓
        Split into 3 branches:
           ├→ Add Element 0 to selection
           ├→ Add coincident points (if any)
           └→ Add closed path endpoint (Element N)
           ↓
RESULT: Both Element 0 and Element N selected
        + all their handles visible
```

---

## 7. Data Structure Flow

```
PATH DATA HIERARCHY:

VectorPath
├─ elements: [PathElement]
│  ├─ Element 0: PathElement.move(to: VectorPoint)
│  ├─ Element 1: PathElement.curve(to:, control1:, control2:)
│  ├─ Element 2: PathElement.curve(to:, control1:, control2:)
│  └─ Element N: PathElement.close
│
ID MAPPING:

PointID {
  shapeID: UUID         ← Which shape
  pathIndex: Int = 0    ← Always 0 (single path per shape)
  elementIndex: Int     ← Which element in path.elements
}

HandleID {
  shapeID: UUID         ← Which shape
  pathIndex: Int = 0    ← Always 0
  elementIndex: Int     ← Which element
  handleType: .control1 or .control2  ← Which handle
}
```

---

## 8. Smoothness Detection Flow Chart

```
isPointSmooth(handleID) called
     ↓
Is this a closed path with coincident endpoints?
     ├─ YES → Check isCoincidentPointSmooth()
     │         └─ Check if E1.c1 and E4.c2 collinear?
     │            └─ YES → SMOOTH
     │            └─ NO → NOT SMOOTH
     │
     └─ NO → Check regular smoothness
              ├─ Get incoming and outgoing handles
              ├─ Calculate vectors from anchor
              ├─ Normalize vectors
              ├─ Calculate dot product
              └─ Return (dot < -0.98)

Thresholds:
- dot < -0.98 means angle ≥ 170° (allows 10° tolerance from perfect 180°)
- Handle length > 0.1 units (not collapsed)
```

---

## 9. Tolerance Visualization

```
DISTANCE-BASED COINCIDENCE:

Point A
  │
  │ distance ≤ 1.0 units?
  │
  └──────────────────┬─────────────────┐
                     │                 │
                    YES               NO
                     │                 │
              Coincident          Not coincident
              
Visual:
A ─ < 1.0 unit → B  (COINCIDENT)
A ─ > 1.0 unit ──→ C  (NOT COINCIDENT)

ANGLE-BASED SMOOTHNESS:

Perfect 180°:
→ ← (dot = -1.0)

170° (at tolerance boundary):
↗ ↙ (dot = -0.98 = cos(170°))

160° (beyond tolerance):
→ ← but not straight (dot > -0.98)

CODE:
return dot < -0.98  // Accepts up to ~10° deviation
```

---

## 10. Coordinate System Example

```
ELLIPSE WITH ACTUAL COORDINATES:

        (250, 100)
           E0,E4
            │
     (150,100)────(350,100)
        E4.c2      E1.c1
            │
    ┌───────┼───────┐
    │       │       │
(100,200) (250,200) (400,200)
    │       │       │
    └───────┼───────┘
            │
        (250, 300)

For smoothness check:
- Anchor: (250, 100)
- E1.c1 (handle1): (350, 100)
- E4.c2 (handle2): (150, 100)

Vectors from anchor:
- vec1 = (350-250, 100-100) = (100, 0)
- vec2 = (150-250, 100-100) = (-100, 0)

Normalized:
- norm1 = (1, 0)
- norm2 = (-1, 0)

Dot product:
- 1*(-1) + 0*0 = -1.0  ← PERFECTLY SMOOTH

Code:
return dot < -0.98  // -1.0 < -0.98? YES, SMOOTH!
```

---

## 11. Edit Operation Example

```
USER EDITS ELLIPSE CLOSURE:

Step 1: User selects Element 0 (top point)
        ↓
Step 2: System automatically selects Element 4 too
        ↓
Step 3: User drags Element 1's control1 handle
        ↓
Step 4: checkFirstLastCoincidentForLive() activated
        ├─ Detects: E1.c1 is at boundary
        ├─ Calculates: opposite handle position
        └─ Updates: E4.c2 automatically
        ↓
Step 5: Both handles now maintain collinearity
        ├─ E1.c1 and E4.c2 still form straight line
        └─ Ellipse closure remains smooth

Result: Seamless editing with automatic tangency preservation
```

---

## 12. Performance Consideration

```
COINCIDENT POINT FINDING COMPLEXITY:

for layer in layers:
  for shape in shapes:
    for element in shape.elements:
      if distance(element.point, targetPoint) <= tolerance:
        add to results

Complexity: O(S × E) where
  S = total shapes in document
  E = average elements per shape

OPTIMIZATION:
- Only iterate visible shapes
- Use active shape selection when available
- Calculate distance once, check if <= tolerance

SMOOTHNESS CHECK COMPLEXITY:

Regular point: O(1)  - Just vector math
Coincident point: O(1)  - Same vector math
(No iteration needed)

Both are O(1) operations, very efficient!
```

