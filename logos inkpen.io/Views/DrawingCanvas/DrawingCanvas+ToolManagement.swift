//
//  DrawingCanvas+ToolManagement.swift
//  logos inkpen.io
//
//  Tool management functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // ✅ EXPLICIT USER ACTION: Auto-finish bezier path when user switches away from pen tool
        // This is standard Adobe Illustrator behavior and represents explicit user intent to stop drawing
        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            print("🔧 USER SWITCHED TOOLS: Auto-finishing current bezier path (explicit user action)")
            finishBezierPath()
        }
        
        // CRITICAL FIX: Preserve text box font settings when switching tools
        // This prevents font settings from changing when switching between font tool and arrow tool
        if previousTool == .font && newTool == .selection {
            print("🔧 TOOL SWITCH: Font → Arrow: Preserving all text box font settings")
            // Convert editing text to selected state (BLUE → GREEN)
            if isEditingText, let editingTextID = editingTextID {
                finishTextEditingButKeepSelected(editingTextID)
            }
            // Font settings remain unchanged per text box UUID
        }
        
        if previousTool == .selection && newTool == .font {
            print("🔧 TOOL SWITCH: Arrow → Font: Preserving all text box font settings")
            // Keep selected text boxes selected (GREEN stays GREEN)
            // Font settings remain unchanged per text box UUID
        }
        
        // SURGICAL FIX: Cancel text editing when switching away from font tool to other tools (not arrow)
        if previousTool == .font && newTool != .font && newTool != .selection && isEditingText {
            print("🔧 USER SWITCHED TOOLS: Canceling text editing (switched away from font tool to non-arrow tool)")
            finishTextEditing()
        }
        
        // PROFESSIONAL TOOL BEHAVIOR: Clear regular selection when switching TO direct selection or convert point tools
        if (newTool == .directSelection || newTool == .convertAnchorPoint) &&
            (previousTool != .directSelection && previousTool != .convertAnchorPoint) {
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            print("🎯 Switched to Direct Selection/Convert Point - cleared regular selection handles")
        }
        
        // Clear direct selection state when switching away from direct selection tools
        if (previousTool == .directSelection || previousTool == .convertAnchorPoint) &&
            (newTool != .directSelection && newTool != .convertAnchorPoint) {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
            print("🎯 Switched away from Direct Selection/Convert Point - cleared direct selection state")
        }
        
        previousTool = newTool
    }
    
    // NEW: Helper function to finish text editing but keep text selected
    private func finishTextEditingButKeepSelected(_ textID: UUID) {
        // Stop editing mode (BLUE → GREEN)
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
            document.textObjects[textIndex].isEditing = false
        }
        
        // Keep text selected (GREEN state)
        document.selectedTextIDs = [textID]
        
        // Clear editing flags
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)
        
        print("🎯 TEXT STATE: \(textID.uuidString.prefix(8)) → GREEN (Selected, not editing)")
        print("🔧 FONT SETTINGS: Preserved all typography properties for this text box")
    }
} 