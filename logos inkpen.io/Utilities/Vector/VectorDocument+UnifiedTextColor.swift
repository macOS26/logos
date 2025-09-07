//
//  VectorDocument+UnifiedTextColor.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Text Color Management
extension VectorDocument {
    
    // Note: Text styling properties are not stored directly on VectorShape
    // These functions are placeholders for future text styling implementation
    
    func updateTextColorInUnified(id: UUID, color: VectorColor) {
        // Text color is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextFontFamilyInUnified(id: UUID, fontFamily: String) {
        // Font family is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextFontSizeInUnified(id: UUID, fontSize: Double) {
        // Font size is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextFontWeightInUnified(id: UUID, fontWeight: String) {
        // Font weight is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextAlignmentInUnified(id: UUID, alignment: String) {
        // Text alignment is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        // Text fill color is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        // Text stroke color is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        // Text typography is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextIsEditingInUnified(id: UUID, isEditing: Bool) {
        // Update isEditing flag in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isEditing = isEditing
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
}