//
//  DrawingCanvas+Pan.swift
//  logos inkpen.io
//
//  Pan gesture (hand tool) functionality
//

import SwiftUI

// Toggle to enable/disable verbose logging for the Hand Tool (pan gesture)
fileprivate let enableHandToolLogging = false

extension DrawingCanvas {
    internal func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL HAND TOOL: Perfect cursor-to-canvas synchronization
        // Based on Adobe Illustrator, MacroMedia FreeHand, Inkscape, and CorelDRAW standards
        // Reference: US Patent 6097387A - "Dynamic control of panning operation in computer graphics"
        
        // CRITICAL FIX: Only initialize state once per drag operation
        // State should only be reset at the END of drag, not during drag
        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            // Capture initial state - this is the "reference location" from Sony's patent
            initialCanvasOffset = document.canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true  // PROFESSIONAL GESTURE COORDINATION
            
            if enableHandToolLogging {
                print("✋ HAND TOOL: Established reference location (Professional Standard), UI responsive")
                print("   Reference canvas offset: (\(String(format: "%.1f", initialCanvasOffset.x)), \(String(format: "%.1f", initialCanvasOffset.y)))")
                print("   Reference cursor location: (\(String(format: "%.1f", handToolDragStart.x)), \(String(format: "%.1f", handToolDragStart.y)))")
            }
        }
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - handToolDragStart.x,
            y: value.location.y - handToolDragStart.y
        )
        
        // PROFESSIONAL IMPLEMENTATION: Direct cursor-to-canvas mapping
        // The point under the cursor at drag start stays exactly under the cursor throughout the drag
        // This is the gold standard used by Adobe Illustrator, FreeHand, Inkscape, and CorelDRAW
        document.canvasOffset = CGPoint(
            x: initialCanvasOffset.x + cursorDelta.x,
            y: initialCanvasOffset.y + cursorDelta.y
        )
        
        // Professional verification logging (only for significant movements)
        if enableHandToolLogging && (abs(cursorDelta.x) > 10 || abs(cursorDelta.y) > 10) {
            print("✋ HAND TOOL: Perfect sync maintained - delta: (\(String(format: "%.1f", cursorDelta.x)), \(String(format: "%.1f", cursorDelta.y))), UI responsive")
        }
    }
} 