//
//  DrawingCanvas+ViewComposition.swift
//  logos inkpen.io
//
//  View composition functionality
//

import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func canvasOverlays(geometry: GeometryProxy) -> some View {
        // Current drawing path (while drawing)
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)  // ✅ FIXED: Added missing anchor
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
        
        // PROFESSIONAL REAL-TIME BEZIER PATH (Adobe Illustrator style - shows actual path with real colors)
        // Note: Real bezier shapes are now shown as actual VectorShapes in the document
        
        // PROFESSIONAL RUBBER BAND PREVIEW (Adobe Illustrator Standards)
        rubberBandPreview(geometry: geometry)
        
        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        
        // Selection handles for selected shapes (EXCEPT during pen tool drawing)
        if !(document.currentTool == .bezierPen && isBezierDrawing) {
            SelectionHandlesView(
                document: document,
                geometry: geometry
            )
        }
        
        // Direct selection points and handles
        // Show direct selection UI for both Direct Selection tool AND Convert Point tool
        if document.currentTool == .directSelection || document.currentTool == .convertAnchorPoint {
            ProfessionalDirectSelectionView(
                document: document,
                selectedPoints: selectedPoints,
                selectedHandles: selectedHandles,
                directSelectedShapeIDs: directSelectedShapeIDs,
                geometry: geometry
            )
        }
    }
    
    @ViewBuilder
    internal func canvasBaseContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // BRILLIANT USER SOLUTION: No more manual background!
            // Canvas is now a regular layer/shape that auto-syncs with everything else
            
            // Grid (if enabled)
            if document.snapToGrid {
                GridView(document: document, geometry: geometry)
            }
            
            // Render all layers and shapes (including the canvas layer!)
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                if document.layers[layerIndex].isVisible {
                    LayerView(
                        layer: document.layers[layerIndex],
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        selectedShapeIDs: document.selectedShapeIDs,
                        viewMode: document.viewMode
                    )
                }
            }
            
            // RENDER TEXT OBJECTS using Core Graphics (NO CORE TEXT)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObj = document.textObjects[textIndex]
                if textObj.isVisible {
                    TextObjectView(
                        textObject: textObj,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        isSelected: document.selectedTextIDs.contains(textObj.id),
                        isEditing: isEditingText && editingTextID == textObj.id
                    )
                }
            }
            
            canvasOverlays(geometry: geometry)
        }
    }
    
    @ViewBuilder
    internal func canvasMainContent(geometry: GeometryProxy) -> some View {
        canvasBaseContent(geometry: geometry)
            .clipped()
            .onAppear {
                setupCanvas(geometry: geometry)
                setupKeyEventMonitoring()
                setupToolKeyboardShortcuts()
                previousTool = document.currentTool
            }
            .onDisappear {
                teardownKeyEventMonitoring()
            }
            .onChange(of: document.currentTool) { oldTool, newTool in
                handleToolChange(oldTool: oldTool, newTool: newTool)
            }
            .onTapGesture { location in
                // UNIFIED COORDINATE SYSTEM: Handle ALL clicks (canvas + pasteboard) with SwiftUI
                // This gives perfect accuracy everywhere using the same coordinate system
                print("🎯 UNIFIED TAP GESTURE at screen: \(location)")
                handleTap(at: location, geometry: geometry)
            }
            .onHover { isHovering in
                // Enable mouse tracking for rubber band preview
            }
            .onContinuousHover { phase in
                handleHover(phase: phase, geometry: geometry)
            }
            .simultaneousGesture(
                // PROFESSIONAL DRAG GESTURE - Only for canvas operations, doesn't block UI
                // PASTEBOARD FIX: Use 0-pixel threshold for maximum sensitivity on pasteboard
                // Canvas vs Pasteboard handling is done in the drag logic
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, geometry: geometry)
                    }
            )
            .simultaneousGesture(
                // PROFESSIONAL ZOOM GESTURE - Separate from drag to avoid conflicts
                MagnificationGesture()
                    .onChanged { value in
                        handleZoomGestureChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleZoomGestureEnded(value: value, geometry: geometry)
                    }
            )
            .onTapGesture(count: 2) { location in
                fitToPage(geometry: geometry)
            }
            .onChange(of: document.zoomRequest) {
                if let request = document.zoomRequest {
                    handleZoomRequest(request, geometry: geometry)
                }
            }
            .contextMenu {
                directSelectionContextMenu
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FitCanvasToPage"))) { _ in
                // Auto-center view after canvas fit operation
                fitToPage(geometry: geometry)
            }
    }
} 