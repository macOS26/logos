//
//  StatusBar.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct StatusBar: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        HStack {
            // Current Tool with context-sensitive instructions
            HStack(spacing: 2) {
                Text("Tool: \(document.currentTool.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // PROFESSIONAL BEZIER TOOL HINTS
                if document.currentTool == .bezierPen {
                    Text("• Click to place points • Click near first point to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if document.currentTool == .directSelection {
                    Text("• Select anchor points and handles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if document.currentTool == .warp {
                    Text("• Select objects to warp • Drag handles to distort")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Selection Info with Object Dimensions (single line)
            HStack {
                if document.selectedObjectIDs.isEmpty {
                    Text("No selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let totalSelected = document.selectedObjectIDs.count
                    
                    // Show selection count and dimensions on one line with precision
                    if let bounds = getSelectionBounds() {
                        Text("\(totalSelected) selected  •  W: \(formatPreciseDimension(bounds.width))pt H: \(formatPreciseDimension(bounds.height))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(totalSelected) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Document Info - FIXED: Show proper decimals for dimensions
            Text("Size: \(formatDimension(document.settings.width))×\(formatDimension(document.settings.height)) \(document.settings.unit.abbreviation)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Zoom Level
            Text("Zoom: \(Int(document.zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .top
        )
    }
    
    /// Format dimension values to show up to 5 decimal places
    private func formatDimension(_ value: Double) -> String {
        // Always show up to 5 decimal places, but trim trailing zeros
        let formatted = String(format: "%.5f", value)
        
        // Remove trailing zeros and decimal point if not needed
        if formatted.contains(".") {
            var trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmed.hasSuffix(".") {
                trimmed = String(trimmed.dropLast())
            }
            return trimmed
        }
        
        return formatted
    }
    
    /// Format precise dimension values in points (always show decimals)
    private func formatPreciseDimension(_ value: CGFloat) -> String {
        // Always show up to 5 decimal places for points, trim trailing zeros
        let formatted = String(format: "%.5f", value)
        
        // Remove trailing zeros but keep at least one decimal
        if formatted.contains(".") {
            var trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmed.hasSuffix(".") {
                trimmed = String(trimmed.dropLast())
            }
            return trimmed
        }
        
        return formatted
    }
    
    /// Calculate combined bounds of all selected objects
    private func getSelectionBounds() -> CGRect? {
        var combinedBounds: CGRect?
        
        // Include selected shapes
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               !shape.isTextObject,
               document.selectedShapeIDs.contains(shape.id) {
                let shapeBounds = shape.bounds.applying(shape.transform)
                if combinedBounds == nil {
                    combinedBounds = shapeBounds
                } else {
                    combinedBounds = combinedBounds!.union(shapeBounds)
                }
            }
        }
        
        // Include selected text objects
        for unifiedObject in document.unifiedObjects.sorted(by: { $0.orderID < $1.orderID }) {
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject,
               document.selectedTextIDs.contains(shape.id),
               let textObj = VectorText.from(shape) {
                // Calculate absolute text bounds
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                
                if combinedBounds == nil {
                    combinedBounds = textBounds
                } else {
                    combinedBounds = combinedBounds!.union(textBounds)
                }
            }
        }
        
        return combinedBounds
    }
}
