//
//  DrawingCanvas+DirectSelContextMenu.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/15/25.
//

import SwiftUI
    
extension DrawingCanvas {
    @ViewBuilder
    internal var directSelectionContextMenu: some View {
        // PROFESSIONAL BEZIER PEN CONTEXT MENU OPTIONS
        if document.currentTool == .bezierPen && isBezierDrawing && bezierPoints.count >= 3 {
            Button("Close Path") {
                closeBezierPath()
            }
                            .keyboardShortcut("j", modifiers: [.command]) // Professional standard
            
            Button("Finish Path (Open)") {
                finishBezierPath()
            }
            .keyboardShortcut(.return)
            
            Button("Cancel Path") {
                cancelBezierDrawing()
            }
            .keyboardShortcut(.escape)
        }
        
        if document.currentTool == .directSelection && !selectedPoints.isEmpty {
            Button("Close Path") {
                closeSelectedPaths()
            }
            // Note: Global Command+Shift+J shortcut handles this in MainView
            
            Button("Delete Selected") {
                deleteSelectedPoints()
            }
            .keyboardShortcut(.delete)
            
            Divider()
            
            Button("Analyze Coincident Points") {
                analyzeCoincidentPoints()
            }
        }
        
        // Clipping mask actions when shapes selected
        if !document.selectedObjectIDs.isEmpty {
            Divider()
            Button("Make Clipping Mask") {
                document.makeClippingMaskFromSelection()
            }
            .disabled(document.selectedObjectIDs.count < 2)
            Button("Release Clipping Mask") {
                document.releaseClippingMaskForSelection()
            }
        }
    }

}
