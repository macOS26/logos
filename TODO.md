# TODO: Break Down LayerView.swift

## Phase 1: Extract Core Structures
- [ ] Extract `ClippingMaskShapeView` to `LayerView+ClippingMask.swift`
- [ ] Extract `ShapeMaskView` to `LayerView+ShapeMask.swift`
- [ ] Extract `SingleMaskShape` to `LayerView+SingleMaskShape.swift`
- [ ] Extract `GroupMaskContainer` to `LayerView+GroupMaskContainer.swift`

## Phase 2: Extract Transform Tool Handles
- [ ] Extract `ScaleHandles` to `LayerView+ScaleHandles.swift`
- [ ] Extract `RotateHandles` to `LayerView+RotateHandles.swift`
- [ ] Extract `ShearHandles` to `LayerView+ShearHandles.swift`
- [ ] Extract `EnvelopeHandles` to `LayerView+EnvelopeHandles.swift`
- [ ] Extract `PersistentWarpMarquee` to `LayerView+PersistentWarpMarquee.swift`

## Phase 3: Extract Text Tool Handles
- [ ] Extract `TextRotateHandles` to `LayerView+TextRotateHandles.swift`
- [ ] Extract `TextShearHandles` to `LayerView+TextShearHandles.swift`
- [ ] Extract `TextScaleHandles` to `LayerView+TextScaleHandles.swift`

## Phase 4: Extract Gradient and SVG Renderers
- [ ] Extract `GradientFillView` to `LayerView+GradientFillView.swift`
- [ ] Extract `GradientStrokeView` to `LayerView+GradientStrokeView.swift`
- [ ] Extract `GradientNSView` to `LayerView+GradientNSView.swift`
- [ ] Extract `GradientStrokeNSView` to `LayerView+GradientStrokeNSView.swift`
- [ ] Extract `SVGShapeRenderer` to `LayerView+SVGShapeRenderer.swift`
- [ ] Extract `SVGRenderingView` to `LayerView+SVGRenderingView.swift`

## Phase 5: Extract Extensions and Utilities
- [ ] Extract `BlendMode` extension to `LayerView+BlendMode.swift`
- [ ] Extract `CGLineCap` extension to `LayerView+CGLineCap.swift`
- [ ] Extract `CGLineJoin` extension to `LayerView+CGLineJoin.swift`
- [ ] Extract `ShapeView` gradient rendering helper functions to `LayerView+GradientHelpers.swift`

## Phase 6: Clean Up Main LayerView.swift
- [ ] Remove all extracted code from main file
- [ ] Keep only the main `LayerView` struct
- [ ] Ensure all imports and dependencies are correct
- [ ] Test build after each extraction

## Build and Commit Process
After each extraction:
1. `xcf build` - Build project
2. If successful: `git commit` with descriptive message
3. If failed: Fix issues and repeat
