//
//  VectorDocument+TextManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit

// MARK: - Text Management
extension VectorDocument {
    
    // MARK: - Professional Text Management
    func addText(_ text: VectorText) {
        saveToUndoStack()
        textObjects.append(text)
        
        // Add to unified system with current layer
        if let layerIndex = selectedLayerIndex {
            addTextToUnifiedSystem(text, layerIndex: layerIndex)
        }
        
        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
        syncSelectionArrays()
    }
    
    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < layers.count else {
            // Fallback to global text objects if no valid layer
            addText(text)
            return
        }
        
        saveToUndoStack()
        
        // Add text to global array (for rendering compatibility)
        textObjects.append(text)
        
        // Associate text with specific layer by storing layer reference
        // Note: We still use global textObjects for rendering, but track layer association
        var modifiedText = text
        modifiedText.layerIndex = layerIndex
        textObjects[textObjects.count - 1] = modifiedText
        
        // Add to unified system
        addTextToUnifiedSystem(modifiedText, layerIndex: layerIndex)
        
        selectedTextIDs = [text.id]
        selectedObjectIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
        selectedLayerIndex = layerIndex // Select the layer we added text to
        syncSelectionArrays()
        
        Log.fileOperation("📝 Added editable text to layer \(layerIndex) (\(layers[layerIndex].name))", level: .info)
    }
    
    func removeSelectedText() {
        saveToUndoStack()
        textObjects.removeAll { selectedTextIDs.contains($0.id) }
        selectedTextIDs.removeAll()
    }
    
    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        var newTextIDs: Set<UUID> = []
        
        for textID in selectedTextIDs {
            if let originalText = textObjects.first(where: { $0.id == textID }) {
                // Create duplicate with slight offset
                var duplicateText = originalText
                duplicateText.id = UUID() // New unique ID
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10, // 10pt offset
                    y: originalText.position.y + 10
                )
                // CRITICAL FIX: Don't call updateBounds() - preserve original bounds from ProfessionalTextCanvas
                // duplicateText.updateBounds() - REMOVED because it uses old single-line algorithm
                
                textObjects.append(duplicateText)
                newTextIDs.insert(duplicateText.id)
            }
        }
        
        // Select the duplicated text objects
        selectedTextIDs = newTextIDs
        Log.info("✅ Duplicated \(newTextIDs.count) text objects", category: .fileOperations)
    }
    
    func updateSelectedTextProperty<T>(_ keyPath: WritableKeyPath<VectorText, T>, value: T) {
        saveToUndoStack()
        for i in textObjects.indices {
            if selectedTextIDs.contains(textObjects[i].id) {
                textObjects[i][keyPath: keyPath] = value
                // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
                // textObjects[i].updateBounds() - REMOVED because it uses old single-line algorithm
            }
        }
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION - USES WORKING PROFESSIONALTEXT IMPLEMENTATION
    func convertSelectedTextToOutlines() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        let selectedTexts = textObjects.filter { selectedTextIDs.contains($0.id) }
        var newShapeIDs: Set<UUID> = []
        
        // CRITICAL FIX: Track total shapes across all layers before conversion
        let totalShapesBefore = layers.reduce(0) { $0 + $1.shapes.count }
        
        for textObj in selectedTexts {
            // CRITICAL: Use ProfessionalTextCanvas convertToPath logic instead of VectorText.convertToOutlines()
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)
            
            // Call the new word-by-word convertToPath method
            viewModel.convertToPath()
        }
        
        // CRITICAL FIX: Track total shapes across all layers after conversion
        let totalShapesAfter = layers.reduce(0) { $0 + $1.shapes.count }
        let newShapesCreated = totalShapesAfter - totalShapesBefore
        
        if newShapesCreated > 0 {
            // Find the newly created shapes by comparing before/after
            var allShapesAfter: [VectorShape] = []
            for layer in layers {
                allShapesAfter.append(contentsOf: layer.shapes)
            }
            
            // Get the last N shapes (where N = newShapesCreated)
            let newShapes = Array(allShapesAfter.suffix(newShapesCreated))
            newShapeIDs = Set(newShapes.map { $0.id })
            
            selectedShapeIDs = newShapeIDs
            Log.info("✅ TEXT TO OUTLINES: \(newShapeIDs.count) text object(s) converted with character-by-character normalization", category: .fileOperations)
        } else {
            Log.error("❌ TEXT TO OUTLINES FAILED: No new shapes were created", category: .error)
        }
        
        // Remove the original text objects
        let removedTextCount = textObjects.count
        textObjects.removeAll { selectedTextIDs.contains($0.id) }
        let actuallyRemovedCount = removedTextCount - textObjects.count
        
        Log.fileOperation("🗑️ TEXT REMOVAL: Removed \(actuallyRemovedCount) text objects from textObjects array", level: .info)
        
        selectedTextIDs.removeAll()
        
        // Sync unified objects after text removal
        updateUnifiedObjectsOptimized()
        
        // CRITICAL: Force cleanup of any remaining unified objects that reference deleted text
        cleanupUnifiedObjectsAfterTextConversion()
        
        Log.info("✅ TEXT TO OUTLINES COMPLETE: Bezier handles now visible with Direct Selection Tool (A)", category: .fileOperations)
    }
    
    /// CRITICAL: Clean up unified objects after text conversion to ensure deleted text doesn't remain in UI
    private func cleanupUnifiedObjectsAfterTextConversion() {
        let beforeCount = unifiedObjects.count
        
        // Remove any unified objects that reference text objects that no longer exist
        unifiedObjects.removeAll { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject {
                let textStillExists = textObjects.contains { $0.id == shape.id }
                if !textStillExists {
                    Log.fileOperation("🗑️ CLEANUP: Removing unified object for deleted text '\(shape.textContent ?? "")' (ID: \(shape.id.uuidString.prefix(8)))", level: .info)
                }
                return !textStillExists
            }
            return false
        }
        
        let afterCount = unifiedObjects.count
        let removedCount = beforeCount - afterCount
        
        if removedCount > 0 {
            Log.fileOperation("🧹 UNIFIED OBJECTS CLEANUP: Removed \(removedCount) orphaned text references", level: .info)
        }
    }
    
    func selectTextAt(_ point: CGPoint) -> VectorText? {
        // Search from top to bottom (last drawn first) using unified objects
        for unifiedObject in unifiedObjects.reversed() {
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject {
                if shape.isVisible && !shape.isLocked {
                    let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let transformedBounds = CGRect(
                        x: position.x + shape.bounds.minX,
                        y: position.y + shape.bounds.minY,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    if transformedBounds.contains(point) {
                        selectedObjectIDs = [unifiedObject.id]
                        syncSelectionArrays() // Keep legacy arrays in sync
                        
                        // Convert VectorShape back to VectorText for return value
                        if let textContent = shape.textContent, let typography = shape.typography {
                            return VectorText(
                                content: textContent,
                                typography: typography,
                                position: position,
                                transform: .identity,
                                isVisible: shape.isVisible,
                                isLocked: shape.isLocked,
                                isEditing: shape.isEditing ?? false,
                                layerIndex: unifiedObject.layerIndex,
                                isPointText: shape.isPointText ?? true,
                                cursorPosition: shape.cursorPosition ?? 0,
                                areaSize: shape.areaSize
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
    
    func updateTextContent(_ textID: UUID, content: String) {
        // PERFORMANCE FIX: Don't save to undo stack on every keystroke - only when editing ends
        // saveToUndoStack() - REMOVED to prevent performance issues during typing
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].content = content
            // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
            // textObjects[index].updateBounds() - REMOVED because it uses old single-line algorithm
            updateUnifiedObjectsOptimized()
        }
    }
    
    func setTextEditing(_ textID: UUID, isEditing: Bool) {
        // PERFORMANCE FIX: No undo saving for text editing state changes
        // User doesn't want text changes saved to undo stack
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].isEditing = isEditing
        }
    }
    
    func updateTextTypography(_ textID: UUID, update: (inout TypographyProperties) -> Void) {
        // PERFORMANCE FIX: No undo saving for typography changes - user doesn't want text changes saved
        // saveToUndoStack() - REMOVED per user request
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            update(&textObjects[index].typography)
            // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now  
            // textObjects[index].updateBounds() - REMOVED because it uses old single-line algorithm
            updateUnifiedObjectsOptimized()
        }
    }
    
    // CRITICAL PROFESSIONAL FEATURE: Text to Outlines Conversion
    func convertTextToOutlines(_ textID: UUID) {
        saveToUndoStack()
        
        guard let textIndex = textObjects.firstIndex(where: { $0.id == textID }),
              let layerIndex = selectedLayerIndex else {
            Log.error("❌ Failed to find text or layer for conversion", category: .error)
            return
        }
        
        let textObject = textObjects[textIndex]
        
        // VALIDATION: Check for empty text content
        guard !textObject.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.error("❌ Cannot convert empty text to outlines. Please type some text first.", category: .error)
            return
        }
        
        Log.fileOperation("🎯 Converting text '\(textObject.content)' to vector outlines...", level: .info)
        
        // CRITICAL FIX: Use the proper nsFont from typography which includes weight and style
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textObject.typography.nsFont, // This includes proper weight and style
            .kern: textObject.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: textObject.content, attributes: attributes)
        
        // Create CTFramesetter to generate paths
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Calculate text bounds
        let textBounds = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        
        // Create frame path
        let framePath = CGPath(rect: CGRect(origin: .zero, size: textBounds), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)
        
        // CRITICAL FIX: Extract all glyph paths and combine into single grouped shape
        var allPathElements: [PathElement] = []
        
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        
        if lineCount > 0 {
            var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
            CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &lineOrigins)
            
            for lineIndex in 0..<lineCount {
                let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex), to: CTLine.self)
                let runs = CTLineGetGlyphRuns(line)
                let runCount = CFArrayGetCount(runs)
                
                for runIndex in 0..<runCount {
                    let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, runIndex), to: CTRun.self)
                    let runAttributes = CTRunGetAttributes(run) as? [String: Any]
                    
                    guard let font = runAttributes?[NSAttributedString.Key.font.rawValue] as? NSFont else { continue }
                    
                    let glyphCount = CTRunGetGlyphCount(run)
                    if glyphCount == 0 { continue }
                    
                    var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                    var positions = [CGPoint](repeating: .zero, count: glyphCount)
                    
                    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
                    
                    // Convert NSFont to CTFont for proper path creation
                    let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
                    let _ = CTFontGetAscent(ctFont)
                    
                    // Convert each glyph to path elements
                    for glyphIndex in 0..<glyphCount {
                        let glyph = glyphs[glyphIndex]
                        let glyphPosition = positions[glyphIndex]
                        
                        if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                            // CRITICAL FIX: Apply coordinate system transformation for SwiftUI
                            // Core Graphics uses bottom-left origin, SwiftUI uses top-left
                            var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y-axis
                                .translatedBy(
                                    x: textObject.position.x + Double(glyphPosition.x),
                                    y: -textObject.position.y //- Double(lineOrigins[lineIndex].y)
                                )
                            
                            if let transformedPath = glyphPath.copy(using: &transform) {
                                // Convert transformed CGPath to VectorPath elements
                                let glyphElements = convertCGPathToVectorPathElements(transformedPath)
                                allPathElements.append(contentsOf: glyphElements)
                            }
                        }
                    }
                }
            }
        }
        
        // CRITICAL FIX: Create single grouped shape with all letters combined
        if !allPathElements.isEmpty {
            let vectorPath = VectorPath(elements: allPathElements, isClosed: false) // Let individual letters handle closing
            let outlineShape = VectorShape(
                name: "Text Outline: \(textObject.content)",
                path: vectorPath,
                strokeStyle: textObject.typography.hasStroke ? StrokeStyle(color: textObject.typography.strokeColor, width: textObject.typography.strokeWidth, placement: .center, opacity: textObject.typography.strokeOpacity) : nil,
                fillStyle: FillStyle(color: textObject.typography.fillColor, opacity: textObject.typography.fillOpacity),
                transform: .identity, // No additional transform needed
                isGroup: false // Single unified shape, not a group
            )
            
            // Add to current layer
            layers[layerIndex].shapes.append(outlineShape)
            
            // Remove original text object
            textObjects.remove(at: textIndex)
            selectedTextIDs.remove(textID)
            
            // Select the created outline shape
            selectedShapeIDs = [outlineShape.id]
        }
        // Force UI update
        objectWillChange.send()
    }
    
    // Helper function to convert CGPath to VectorPath elements
    private func convertCGPathToVectorPathElements(_ cgPath: CGPath) -> [PathElement] {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return elements
    }
    
    // Helper function to convert CGPath to VectorPath
    private func convertCGPathToVectorPath(_ cgPath: CGPath, offset: CGPoint = .zero) -> VectorPath {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x + offset.x, point.y + offset.y)))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x + offset.x, point.y + offset.y)))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(point.x + offset.x, point.y + offset.y),
                    control: VectorPoint(control.x + offset.x, control.y + offset.y)
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(point.x + offset.x, point.y + offset.y),
                    control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                    control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return VectorPath(elements: elements, isClosed: elements.contains { if case .close = $0 { return true }; return false })
    }
    
    /// Clear all objects from the document for testing purposes
    func clearAllObjects() {
        saveToUndoStack()
        
        // Clear all shapes from all layers
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll()
        }
        
        // Clear all text objects
        textObjects.removeAll()
        
        // Clear all selections
        selectedObjectIDs.removeAll()
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
        
        Log.info("🧹 Cleared all objects from document", category: .general)
    }
}
