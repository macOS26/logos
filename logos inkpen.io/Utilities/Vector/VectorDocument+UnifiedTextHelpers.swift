//
//  VectorDocument+UnifiedTextHelpers.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Text Helper Functions
extension VectorDocument {
    
    func lockTextInUnified(id: UUID) {
        // Lock text object in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isLocked = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func unlockTextInUnified(id: UUID) {
        // Unlock text object in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isLocked = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func hideTextInUnified(id: UUID) {
        // Hide text object in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isVisible = false
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func showTextInUnified(id: UUID) {
        // Show text object in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.isVisible = true
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        // Text fill opacity is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        // Text stroke width is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func translateAllTextInUnified(delta: CGVector) {
        // Translate all text objects in unified system
        for index in unifiedObjects.indices {
            if case .shape(var shape) = unifiedObjects[index].objectType, shape.isTextObject {
                var transform = shape.transform
                transform.tx += delta.dx
                transform.ty += delta.dy
                shape.transform = transform
                let updatedObject = VectorObject(shape: shape, layerIndex: unifiedObjects[index].layerIndex, orderID: unifiedObjects[index].orderID)
                unifiedObjects[index] = updatedObject
            }
        }
        objectWillChange.send()
    }
    
    func translateTextInUnified(id: UUID, delta: CGVector) {
        // Translate text position in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                var transform = shape.transform
                transform.tx += delta.dx
                transform.ty += delta.dy
                shape.transform = transform
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // Set text editing state in unified system
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
    
    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        // Update text layer in unified system
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            let oldObject = unifiedObjects[index]
            if case .shape(let shape) = oldObject.objectType {
                let updatedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: oldObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextLineHeightInUnified(id: UUID, lineHeight: Double) {
        // Text line height is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextLetterSpacingInUnified(id: UUID, letterSpacing: Double) {
        // Text letter spacing is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextParagraphSpacingInUnified(id: UUID, paragraphSpacing: Double) {
        // Text paragraph spacing is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextIndentInUnified(id: UUID, indent: Double) {
        // Text indent is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextVerticalAlignmentInUnified(id: UUID, verticalAlignment: String) {
        // Text vertical alignment is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextBaselineOffsetInUnified(id: UUID, baselineOffset: Double) {
        // Text baseline offset is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextUnderlineInUnified(id: UUID, underline: Bool) {
        // Text underline is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextStrikethroughInUnified(id: UUID, strikethrough: Bool) {
        // Text strikethrough is not currently stored on VectorShape
        // This would need to be implemented with a proper text styling system
        objectWillChange.send()
    }
    
    func updateTextTransformInUnified(id: UUID, transform: CGAffineTransform) {
        // Update text transform in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.transform = transform
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextSelectionRangeInUnified(id: UUID, selectionRange: NSRange?) {
        // Text selection range is not currently stored on VectorShape
        // This would need to be implemented with a proper text selection system
        objectWillChange.send()
    }
    
    func updateTextOpacityInUnified(id: UUID, opacity: Double) {
        // Update text opacity in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.opacity = opacity
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
}