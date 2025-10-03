//
//  DrawingCanvas+KeyEventHandling.swift
//  logos inkpen.io
//
//  Key event handling functionality
//

import SwiftUI
import AppKit
import Combine

extension DrawingCanvas {
    // MARK: - BEEP PREVENTION - Local Monitor to Handle All Key Events
    internal func setupKeyEventMonitoring() {
        // IMPROVED: Local monitor that prevents beeping but allows modifier key commands
        // ENHANCED: Now also tracks flagsChanged for shift key constraints in transform tools
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { (event: NSEvent) -> NSEvent? in

            // DEBUG: Log EVERY keyDown event to see what's happening
            if event.type == .keyDown {
                let chars = event.charactersIgnoringModifiers ?? "nil"
                let keyCode = event.keyCode
                // Check both document.currentTool and AppState default tool
                let appTool = AppState.shared.defaultTool.rawValue
                let docTool = self.document.currentTool.rawValue
                Log.info("🔑 RAW KEY EVENT: chars='\(chars)' keyCode=\(keyCode) docTool=\(docTool) appTool=\(appTool)", category: .input)
            }

            // CRITICAL FIX: If we're editing text, let ALL keyboard events pass through naturally
            // This prevents the monitor from interfering with text input
            if self.isEditingText {
                return event
            }

            // Also check if NSTextView is first responder as a backup
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder,
               firstResponder is NSTextView {
                // NSTextView is first responder - let it handle naturally
                return event
            }

            // Handle key up events for temporary tool deactivation
            if event.type == .keyUp {
                // Handle spacebar release for temporary hand tool deactivation
                if let characters = event.charactersIgnoringModifiers,
                   characters == " " {
                    self.deactivateTemporaryHandTool()
                    return nil // Consume the event
                }
                return event // Let other keyUp events pass through
            }

            // Handle modifier key changes for transform tools
            if event.type == .flagsChanged {
                // FIXED: Remove async dispatch to prevent race conditions during rapid key events
                // Update modifier states immediately for reliable corner radius tool behavior
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                self.isOptionPressed = event.modifierFlags.contains(.option)
                self.isCommandPressed = event.modifierFlags.contains(.command)
                self.isControlPressed = event.modifierFlags.contains(.control)

                // REMOVED: Repetitive debug logging for key state changes that spam the console
                // Only log significant state changes when needed for debugging

                // Command-based temporary behavior for Arrow tool
                if self.isCommandPressed {
                    // Only when using selection tool, enter temporary command mode
                    if self.document.currentTool == .selection && !self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = true
                        self.temporaryCommandPreviousTool = self.document.currentTool
                        // REMOVED: Repetitive command held logging
                    }
                } else {
                    // Command released: if we were in temporary command mode and didn't permanently switch tools, restore
                    if self.isTemporaryDirectSelectionViaCommand {
                        self.isTemporaryDirectSelectionViaCommand = false
                        // REMOVED: Repetitive command released logging
                        // If we temporarily switched to direct selection, restore the previous tool (selection tool)
                        if self.document.currentTool == .directSelection {
                            // Restore to the tool we saved when Command was first pressed (should be .selection)
                            self.document.currentTool = self.temporaryCommandPreviousTool ?? .selection
                        }
                        // When leaving temp mode, ensure direct selection visuals are cleared
                        if self.document.currentTool == .selection {
                            // Keep selectedShapeIDs, but clear direct selection state
                            self.selectedPoints.removeAll()
                            self.selectedHandles.removeAll()
                            self.directSelectedShapeIDs.removeAll()
                            self.syncDirectSelectionWithDocument()
                            self.document.objectWillChange.send()
                        }
                        self.temporaryCommandPreviousTool = nil
                    }
                }

                return event // Let flagsChanged pass through normally
            }
            
            // HANDLE ARROW KEYS FOR NUDGING (Arrow tool only, no modifiers)
            if let characters = event.charactersIgnoringModifiers {
                let arrowUp = "\u{F700}"    // NSUpArrowFunctionKey
                let arrowDown = "\u{F701}"  // NSDownArrowFunctionKey
                let arrowLeft = "\u{F702}"  // NSLeftArrowFunctionKey
                let arrowRight = "\u{F703}" // NSRightArrowFunctionKey

                // Check if it's an arrow key
                if [arrowUp, arrowDown, arrowLeft, arrowRight].contains(characters) {
                    // Debug: Log the actual tool value
                    Log.info("🔑 ARROW KEY CHECK: Tool is '\(self.document.currentTool.rawValue)' (raw: \(self.document.currentTool))", category: .input)

                    // Only nudge with arrow/selection tool and no modifiers
                    if !event.modifierFlags.contains(.control) &&
                       !event.modifierFlags.contains(.command) &&
                       !event.modifierFlags.contains(.option) &&
                       self.document.currentTool == .selection {

                        var nudgeDirection: CGVector? = nil
                        switch characters {
                        case arrowUp:
                            nudgeDirection = CGVector(dx: 0, dy: -1)
                        case arrowDown:
                            nudgeDirection = CGVector(dx: 0, dy: 1)
                        case arrowLeft:
                            nudgeDirection = CGVector(dx: -1, dy: 0)
                        case arrowRight:
                            nudgeDirection = CGVector(dx: 1, dy: 0)
                        default:
                            break
                        }

                        if let direction = nudgeDirection {
                            // Use grid spacing for nudge amount
                            let gridSpacing = self.document.gridSpacing
                            let nudgeAmount = CGVector(dx: direction.dx * gridSpacing, dy: direction.dy * gridSpacing)
                            self.nudgeSelectedObjects(by: nudgeAmount)
                            Log.info("⬆️ ARROW KEY: Nudged objects by grid spacing (\(gridSpacing))", category: .input)
                            return nil // Consume the event
                        }
                    } else {
                        Log.info("❌ ARROW KEY: Not nudging - tool check failed or modifiers present", category: .input)
                    }
                }
            }

            // ALLOW OTHER MODIFIER KEY COMBINATIONS (Cmd+Z, Cmd+C, etc.) to pass through
            if event.modifierFlags.contains(.command) || 
               event.modifierFlags.contains(.option) || 
               event.modifierFlags.contains(.control) {
                // Let modifier key combinations pass through to menu commands
                return event
            }
            
            // HANDLE SPACEBAR FOR TEMPORARY HAND TOOL
            if let characters = event.charactersIgnoringModifiers,
               characters == " " {
                // Handle spacebar for temporary hand tool activation
                activateTemporaryHandTool()
                return nil // Consume the event to prevent system handling
            }
            
            // HANDLE TAB KEY FOR DESELECT ALL AND BEZIER CURVE CANCELLATION
            if let characters = event.charactersIgnoringModifiers,
               characters == "\t" {
                // CRITICAL: Clear the unified selection first
                self.document.selectedObjectIDs.removeAll()

                // Then sync the legacy arrays
                self.document.syncSelectionArrays()

                // CRITICAL: Also stop editing any text boxes that are in edit mode
                if self.isEditingText {
                    self.finishTextEditing()
                }

                // Stop editing any text that might be in edit mode in the unified system
                for textObject in self.document.getAllTextObjects() {
                    if textObject.isEditing {
                        self.document.setTextEditingInUnified(id: textObject.id, isEditing: false)
                    }
                }

                // Clear any direct selection state
                self.selectedPoints.removeAll()
                self.selectedHandles.removeAll()
                self.directSelectedShapeIDs.removeAll()
                self.syncDirectSelectionWithDocument()
                self.isCornerRadiusEditMode = false

                // CRITICAL FIX: Finish bezier drawing when using bezier pen tool (create unclosed object)
                if self.document.currentTool == .bezierPen && self.isBezierDrawing {
                    Log.info("🎯 TAB KEY: Finished bezier drawing (unclosed object)", category: .selection)
                    self.finishBezierPath()
                }

                // Force UI update
                self.document.objectWillChange.send()

                Log.info("🎯 TAB KEY: Deselected all objects", category: .selection)
                return nil // Consume the event to prevent system handling
            }
            
            // ALLOW TOOL SWITCHING SHORTCUTS to pass through
            // These are single key presses that should trigger tool switching
            let toolSwitchingKeys = Set(["a", "d", "c", "s", "r", "x", "w", "p", "f", "b", "m", "t", "l", "e", "o", "i", "h", "z", "g", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
            
            if let characters = event.charactersIgnoringModifiers?.lowercased(),
               toolSwitchingKeys.contains(characters) {
                // Let tool switching shortcuts pass through to the menu system
                return event
            }
            
            // FOR OTHER SINGLE KEY PRESSES: Consume the event to prevent beeping
            // This tells macOS "we handled this event, don't make error sound"
            return nil
        }
    }
    
    internal func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
            // PROFESSIONAL TOOL KEYBOARD SHORTCUTS (Professional Standards)
    internal func setupToolKeyboardShortcuts() {
        // REMOVED: NSEvent keyboard monitoring was disabled to fix text input issues
        // All keyboard shortcuts have been removed to prevent interference with NSTextView
    }
    
    internal func updateModifierKeyStates(with event: NSEvent) {
        // REMOVED: This method is no longer used since NSEvent monitoring was disabled
        // to fix text input conflicts with NSTextView
    }
    
    // MARK: - Temporary Hand Tool (Spacebar)
    
    /// Temporarily activate hand tool when spacebar is pressed
    internal func activateTemporaryHandTool() {
        // Only activate if not already using hand tool and not in temporary mode
        guard document.currentTool != .hand && !isTemporaryHandToolActive else { return }
        
        // Store the current tool to restore later
        temporaryToolPreviousTool = document.currentTool
        isTemporaryHandToolActive = true
        
        // Switch to hand tool
        document.currentTool = .hand
        
        Log.info("✋ SPACEBAR: Temporary Hand Tool activated from \(temporaryToolPreviousTool?.rawValue ?? "unknown")", category: .input)
    }
    
    /// Deactivate temporary hand tool when spacebar is released
    internal func deactivateTemporaryHandTool() {
        // Only deactivate if in temporary mode
        guard isTemporaryHandToolActive, let previousTool = temporaryToolPreviousTool else { return }
        
        // Restore the previous tool
        document.currentTool = previousTool
        isTemporaryHandToolActive = false
        temporaryToolPreviousTool = nil
        
        Log.info("✋ SPACEBAR: Temporary Hand Tool deactivated, restored to \(previousTool.rawValue)", category: .input)
    }

    // MARK: - Object Nudging with Arrow Keys

    /// Nudge selected objects by the specified amount
    internal func nudgeSelectedObjects(by nudgeAmount: CGVector) {
        // Only proceed if we have selected objects
        guard !document.selectedObjectIDs.isEmpty else { return }

        // Save to undo stack before nudging
        document.saveToUndoStack()

        // Nudge each selected object
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(var shape):
                    // Check if this is a group - handle grouped shapes specially
                    if shape.isGroupContainer {
                        // Transform each grouped shape
                        var nudgedGroupedShapes: [VectorShape] = []
                        for var groupedShape in shape.groupedShapes {
                            // Nudge the grouped shape's path
                            var nudgedElements: [PathElement] = []
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                case .line(let to):
                                    nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                                case .curve(let to, let c1, let c2):
                                    nudgedElements.append(.curve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                        control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                    ))
                                case .quadCurve(let to, let c):
                                    nudgedElements.append(.quadCurve(
                                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                        control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                                    ))
                                case .close:
                                    nudgedElements.append(.close)
                                }
                            }
                            groupedShape.path = VectorPath(elements: nudgedElements, isClosed: groupedShape.path.isClosed)
                            groupedShape.updateBounds()
                            nudgedGroupedShapes.append(groupedShape)
                        }
                        shape.groupedShapes = nudgedGroupedShapes
                        shape.updateBounds()
                    } else {
                        // Nudge regular shape's path
                        var nudgedElements: [PathElement] = []
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                nudgedElements.append(.move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                            case .line(let to):
                                nudgedElements.append(.line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy)))
                            case .curve(let to, let c1, let c2):
                                nudgedElements.append(.curve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                                    control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                                ))
                            case .quadCurve(let to, let c):
                                nudgedElements.append(.quadCurve(
                                    to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                                    control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                                ))
                            case .close:
                                nudgedElements.append(.close)
                            }
                        }
                        shape.path = VectorPath(elements: nudgedElements, isClosed: shape.path.isClosed)
                        shape.updateBounds()
                    }

                    // Update the shape in the unified system
                    document.updateEntireShapeInUnified(id: shape.id) { updatedShape in
                        updatedShape = shape
                    }
                }
            }
        }

        // Trigger transform panel update to show new position
        document.objectPositionUpdateTrigger.toggle()

        // Force UI update
        document.objectWillChange.send()
    }
} 
