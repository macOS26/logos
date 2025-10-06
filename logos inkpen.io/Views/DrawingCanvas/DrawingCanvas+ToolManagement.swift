//
//  DrawingCanvas+ToolManagement.swift
//  logos inkpen.io
//
//  Tool management functionality
//

import SwiftUI
import Combine

extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // EXIT CORNER RADIUS MODE when switching tools (any tool change clears this mode)
        if isCornerRadiusEditMode {
            Log.fileOperation("🔧 TOOL SWITCH: Exiting corner radius edit mode", level: .info)
            isCornerRadiusEditMode = false
        }

        // CRITICAL: Stop all text editing when switching away from font tool or to arrow tool
        // This ensures text boxes don't get stuck in editing mode
        if (previousTool == .font || oldTool == .font) && newTool != .font {
            Log.fileOperation("🔧 TOOL SWITCH: Exiting text editing mode when switching away from type tool", level: .info)
            stopAllTextEditing()
        } else if newTool == .selection {
            // Also stop text editing when switching to arrow tool from any tool
            Log.fileOperation("🔧 TOOL SWITCH: Exiting text editing mode when switching to arrow tool", level: .info)
            stopAllTextEditing()
        }

        // ✅ EXPLICIT USER ACTION: Auto-finish bezier path when user switches away from pen tool
        // This is standard professional behavior and represents explicit user intent to stop drawing
        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            Log.fileOperation("🔧 USER SWITCHED TOOLS: Auto-finishing current bezier path (explicit user action)", level: .info)
            finishBezierPath()
        }

        // ✅ EXPLICIT USER ACTION: Auto-finish freehand path when user switches away from freehand tool
        if previousTool == .freehand && newTool != .freehand && isFreehandDrawing {
            Log.fileOperation("🔧 USER SWITCHED TOOLS: Auto-finishing current freehand path (explicit user action)", level: .info)
            handleFreehandDragEnd()
        }

        // CRITICAL FIX: Preserve text box font settings when switching tools
        // This prevents font settings from changing when switching between font tool and arrow tool
        if previousTool == .font && newTool == .selection {
            Log.fileOperation("🔧 TOOL SWITCH: Type → Arrow: Preserving all text box type settings", level: .info)
            // Font settings remain unchanged per text box UUID
        }

        if previousTool == .selection && newTool == .font {
            Log.fileOperation("🔧 TOOL SWITCH: Arrow → Type: Preserving all text box type settings", level: .info)
            // Keep selected text boxes selected (GREEN stays GREEN)
            // Font settings remain unchanged per text box UUID
        }
        
        // PROFESSIONAL TOOL BEHAVIOR: Auto-convert selections when switching tools
        handleSelectionConversion(from: oldTool, to: newTool)
        
        previousTool = newTool
    }
    
    // NEW: Helper function to stop all text editing across all text boxes
    private func stopAllTextEditing() {
        // Find and stop editing for ALL text boxes that might be in editing mode
        var stoppedCount = 0

        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                stoppedCount += 1
                // Log.info("🛑 STOPPED EDITING: Text box \(shape.id.uuidString.prefix(8))", category: .selection)
            }
        }

        // Clear all editing flags
        if isEditingText {
            isEditingText = false
            editingTextID = nil
            currentCursorPosition = 0
            currentSelectionRange = NSRange(location: 0, length: 0)
        }

        // Reset text editing cursor mode
        isTextEditingMode = false
        // Reset cursor to default arrow when exiting text editing
        NSCursor.arrow.set()

        if stoppedCount > 0 {
            // Log.info("✅ CLEANUP: Stopped editing for \(stoppedCount) text box(es)", category: .selection)
        }
    }

    // Helper function to finish text editing but keep text selected
    private func finishTextEditingButKeepSelected(_ textID: UUID) {
        // Stop editing mode using unified helper (BLUE → GREEN)
        document.setTextEditingInUnified(id: textID, isEditing: false)

        // Keep text selected (GREEN state) - REFACTORED: Use unified objects system
        document.selectedObjectIDs = [textID]

        // Clear editing flags
        isEditingText = false
        editingTextID = nil
        currentCursorPosition = 0
        currentSelectionRange = NSRange(location: 0, length: 0)

        // Log.info("🎯 TEXT STATE: \(textID.uuidString.prefix(8)) → GREEN (Selected, not editing)", category: .selection)
        // Log.info("🔧 TYPE SETTINGS: Preserved all typography properties for this text box", category: .selection)
    }
    
    // MARK: - Selection Conversion Between Tools
    
    /// Handles automatic selection conversion when switching between tools
    private func handleSelectionConversion(from oldTool: DrawingTool, to newTool: DrawingTool) {
        // Log.info("🔧 TOOL CONVERSION: \(oldTool.rawValue) → \(newTool.rawValue)", category: .input)
        
        // CASE 1: Switching TO Arrow Tool (Selection)
        if newTool == .selection {
            // Convert direct selection to regular selection - REFACTORED: Use unified objects system
            if !directSelectedShapeIDs.isEmpty {
                // Log.info("🎯 Converting direct selection to regular selection", category: .selection)
                document.selectedObjectIDs = directSelectedShapeIDs
                // Clear direct selection state
                directSelectedShapeIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                syncDirectSelectionWithDocument()
            }
        }
        
        // CASE 2: Switching TO Direct Selection Tool
        else if newTool == .directSelection {
            // Convert regular selection to direct selection - REFACTORED: Use unified objects system
            if !document.selectedObjectIDs.isEmpty {
                // Log.info("🎯 Converting regular selection to direct selection", category: .selection)
                directSelectedShapeIDs = document.selectedObjectIDs
                // Don't clear regular selection yet - syncDirectSelectionWithDocument will handle it
                // Don't select individual points/handles yet - let user click to refine
                syncDirectSelectionWithDocument() // This will keep selection visible in layers palette
            }
            // CRITICAL FIX: Reset point/handle selections when switching from convert point tool
            // This ensures coincident point detection gets reset properly
            else if oldTool == .convertAnchorPoint || oldTool == .penPlusMinus {
                // Log.info("🎯 Maintaining shape direct selection from convert point tool, resetting point/handle selections", category: .selection)
                // Keep shape-level direct selection but reset point/handle level selections
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                // Log.info("🔄 COINCIDENT RESET: Cleared point/handle selections to reset coincident detection", category: .selection)
            }
        }
        
        // CASE 3: Switching TO Convert Point Tool or Pen +/- Tool
        else if newTool == .convertAnchorPoint || newTool == .penPlusMinus {
            // Convert regular selection to direct selection (same as direct selection tool) - REFACTORED: Use unified objects system
            if !document.selectedObjectIDs.isEmpty {
                // Log.info("🎯 Converting regular selection to direct selection for convert point tool", category: .selection)
                directSelectedShapeIDs = document.selectedObjectIDs
                // Don't clear regular selection yet - syncDirectSelectionWithDocument will handle it
                syncDirectSelectionWithDocument() // This will keep selection visible in layers palette
            }
            // Keep existing direct selection if switching from direct selection tool
            else if oldTool == .directSelection {
                // Log.info("🎯 Maintaining direct selection from direct selection tool", category: .selection)
            }
        }
        
        // CASE 4: Switching AWAY from direct selection tools to other tools (not arrow)
        else if (oldTool == .directSelection || oldTool == .convertAnchorPoint || oldTool == .penPlusMinus) && 
                 newTool != .selection && newTool != .directSelection && newTool != .convertAnchorPoint && newTool != .penPlusMinus {
            // Clear all selection state when switching to drawing tools - REFACTORED: Use unified objects system
            // Log.info("🎯 Switching to drawing tool - clearing all selections", category: .selection)
            document.selectedObjectIDs.removeAll()
            directSelectedShapeIDs.removeAll()
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            syncDirectSelectionWithDocument()
        }
        
        // Force UI update to show new selection state
        document.objectWillChange.send()
    }
    
    // MARK: - Tool State Management
    
    /// Clears tool-specific state when switching tools
    internal func clearToolState() {
        // Clear bezier pen tool state
        if document.currentTool != .bezierPen {
            showClosePathHint = false
            showContinuePathHint = false
        }
        
        // Clear other tool states as needed
        // Add more tool-specific cleanup here
    }
} 
