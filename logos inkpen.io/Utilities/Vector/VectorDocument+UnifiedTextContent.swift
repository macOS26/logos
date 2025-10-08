//
//  VectorDocument+UnifiedTextContent.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI
import Combine

// MARK: - Unified Text Content Management
extension VectorDocument {
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.textContent = content
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int?) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.cursorPosition = cursorPosition
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.transform = CGAffineTransform(translationX: position.x, y: position.y)
            shape.textPosition = position
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.bounds = bounds
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize?) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.areaSize = areaSize
        }
    }
    
    // These layer-based functions are deprecated
    func updateShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        // No longer using layer indices - operations should go through unified system
        Log.warning("updateShapeAtIndex is deprecated - use unified system", category: .general)
    }
    
    func removeShapeAtIndex(layerIndex: Int, shapeIndex: Int) {
        // No longer using layer indices - operations should go through unified system  
        Log.warning("removeShapeAtIndex is deprecated - use unified system", category: .general)
    }
}
