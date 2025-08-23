//
//  UnifiedObjectView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct UnifiedObjectView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    private var objects: [VectorObject] {
        document.getObjectsInStackingOrder()
    }
    
    var body: some View {
        ZStack {
            // Render all objects in proper layer stacking order
            ForEach(objects, id: \.id) { unifiedObject in
                UnifiedObjectContentView(
                    unifiedObject: unifiedObject,
                    document: document,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    selectedObjectIDs: selectedObjectIDs,
                    viewMode: viewMode,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger
                )
            }
        }
    }
}

// MARK: - Unified Object Content View
struct UnifiedObjectContentView: View {
    let unifiedObject: VectorObject
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    var body: some View {
        switch unifiedObject.objectType {
        case .shape(let shape):
            // Render shape using existing ShapeView
            ShapeView(
                shape: shape,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                isSelected: selectedObjectIDs.contains(unifiedObject.id),
                viewMode: viewMode,
                isCanvasLayer: unifiedObject.layerIndex == 1, // Canvas layer is index 1
                isPasteboardLayer: unifiedObject.layerIndex == 0, // Pasteboard layer is index 0
                dragPreviewDelta: dragPreviewDelta,
                dragPreviewTrigger: dragPreviewTrigger
            )
            
        case .text(let text):
            // Render text using existing StableProfessionalTextCanvas
            StableProfessionalTextCanvas(
                document: document,
                textObjectID: text.id,
                dragPreviewDelta: dragPreviewDelta,
                dragPreviewTrigger: dragPreviewTrigger
            )
            .id(text.id)
            .allowsHitTesting(true)
        }
    }
}
