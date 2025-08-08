//
//  DrawingCanvas+ToolManagement.swift
//  logos inkpen.io
//
//  Tool management functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // EXIT CORNER RADIUS MODE when switching tools (REMOVED - use dedicated corner radius tool)
        // if isCornerRadiusEditMode {
        //     print("🔧 TOOL SWITCH: Exiting corner radius edit mode")
        //     isCornerRadiusEditMode = false
        // }
        // ✅ EXPLICIT USER ACTION: Auto-finish bezier path when user switches away from pen tool
        // This is standard Adobe Illustrator behavior and represents explicit user intent to stop drawing
        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            print("🔧 USER SWITCHED TOOLS: Auto-finishing current bezier path (explicit user action)")
            finishBezierPath()
        }
        
        // ✅ EXPLICIT USER ACTION: Auto-finish freehand path when user switches away from freehand tool
        if previousTool == .freehand && newTool != .freehand && isFreehandDrawing {
            print("🔧 USER SWITCHED TOOLS: Auto-finishing current freehand path (explicit user action)")
            handleFreehandDragEnd()
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
        
        // PROFESSIONAL TOOL BEHAVIOR: Auto-convert selections when switching tools
        handleSelectionConversion(from: oldTool, to: newTool)
        
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
    
    // MARK: - Selection Conversion Between Tools
    
    /// Handles automatic selection conversion when switching between tools
    private func handleSelectionConversion(from oldTool: DrawingTool, to newTool: DrawingTool) {
        print("🔧 TOOL CONVERSION: \(oldTool.rawValue) → \(newTool.rawValue)")
        
        // CASE 1: Switching TO Arrow Tool (Selection)
        if newTool == .selection {
            // Convert direct selection to regular selection
            if !directSelectedShapeIDs.isEmpty {
                print("🎯 Converting direct selection to regular selection")
                document.selectedShapeIDs = directSelectedShapeIDs
                // Clear direct selection state
                directSelectedShapeIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                syncDirectSelectionWithDocument()
            }
        }
        
        // CASE 2: Switching TO Direct Selection Tool
        else if newTool == .directSelection {
            // Convert regular selection to direct selection
            if !document.selectedShapeIDs.isEmpty {
                print("🎯 Converting regular selection to direct selection")
                directSelectedShapeIDs = document.selectedShapeIDs
                // Clear regular selection
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                // Don't select individual points/handles yet - let user click to refine
            }
            // Keep existing direct selection if switching from convert point tool
            else if oldTool == .convertAnchorPoint {
                print("🎯 Maintaining direct selection from convert point tool")
            }
        }
        
        // CASE 3: Switching TO Convert Point Tool
        else if newTool == .convertAnchorPoint {
            // Convert regular selection to direct selection (same as direct selection tool)
            if !document.selectedShapeIDs.isEmpty {
                print("🎯 Converting regular selection to direct selection for convert point tool")
                directSelectedShapeIDs = document.selectedShapeIDs
                // Clear regular selection
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
            }
            // Keep existing direct selection if switching from direct selection tool
            else if oldTool == .directSelection {
                print("🎯 Maintaining direct selection from direct selection tool")
            }
        }
        
        // CASE 4: Switching AWAY from direct selection tools to other tools (not arrow)
        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint) && 
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint {
            // Clear all selection state when switching to drawing tools
            print("🎯 Switching to drawing tool - clearing all selections")
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            directSelectedShapeIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }
        
        // Force UI update to show new selection state
        document.objectWillChange.send()
    }
} 