//
//  UnifiedObjectSystemSelectionTests.swift
//  logos inkpen.ioTests
//
//  Created by Claude on 1/21/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemSelectionTests {
    
    // MARK: - Copy/Paste System Tests
    
    @Test @MainActor func testCopyPastePreservesAllTextAttributes() async throws {
        let document = VectorDocument()
        
        // Create text with complex typography
        let originalTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontStyle: .italic,
            fontSize: 48.0,
            lineHeight: 60.0,
            lineSpacing: 5.0,
            letterSpacing: 2.0,
            alignment: .center,
            hasStroke: true,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1)),
            strokeWidth: 2.0,
            strokeOpacity: 0.8,
            fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0)),
            fillOpacity: 0.9
        )
        
        let originalText = VectorText(
            content: "Complex Text",
            typography: originalTypography,
            position: CGPoint(x: 100, y: 200),
            areaSize: CGSize(width: 400, height: 300)
        )
        
        // Add to document and unified system
        document.textObjects.append(originalText)
        document.addTextToUnifiedSystem(originalText, layerIndex: 1)
        document.selectedObjectIDs.insert(originalText.id)
        
        // Simulate copy operation
        let clipboardManager = ClipboardManager.shared
        clipboardManager.copy(from: document)
        
        // Clear selection and paste
        document.selectedObjectIDs.removeAll()
        clipboardManager.paste(to: document)
        
        // Find pasted text in unified objects
        let textShapes = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape
            }
            return nil
        }
        
        #expect(textShapes.count == 2) // Original + pasted
        
        // Find the pasted one (different ID)
        let pastedShape = textShapes.first { $0.id != originalText.id }
        #expect(pastedShape != nil)
        
        if let pastedShape = pastedShape {
            // Verify ALL typography properties preserved
            #expect(pastedShape.typography?.fontFamily == "Herculanum")
            #expect(pastedShape.typography?.fontWeight == .bold)
            #expect(pastedShape.typography?.fontStyle == .italic)
            #expect(pastedShape.typography?.fontSize == 48.0)
            #expect(pastedShape.typography?.lineHeight == 60.0)
            #expect(pastedShape.typography?.lineSpacing == 5.0)
            #expect(pastedShape.typography?.letterSpacing == 2.0)
            #expect(pastedShape.typography?.alignment == .center)
            #expect(pastedShape.typography?.hasStroke == true)
            #expect(pastedShape.typography?.strokeColor == VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1)))
            #expect(pastedShape.typography?.strokeWidth == 2.0)
            #expect(pastedShape.typography?.strokeOpacity == 0.8)
            #expect(pastedShape.typography?.fillColor == VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0)))
            #expect(pastedShape.typography?.fillOpacity == 0.9)
            
            // Verify area size preserved
            #expect(pastedShape.areaSize?.width == 400)
            #expect(pastedShape.areaSize?.height == 300)
            
            // Verify content preserved
            #expect(pastedShape.textContent == "Complex Text")
        }
    }
    
    // MARK: - Selection System Tests
    
    @Test func testSelectedObjectsFromUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add mixed objects
        let shape = VectorShape(name: "Selected Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let text = VectorText(content: "Selected Text", typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black))
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Select both objects
        document.selectedObjectIDs.insert(shape.id)
        document.selectedObjectIDs.insert(text.id)
        
        // Test that we can find selected objects in unified system
        let selectedObjects = document.unifiedObjects.filter { 
            document.selectedObjectIDs.contains($0.id) 
        }
        
        #expect(selectedObjects.count == 2)
        
        // Verify we have one shape and one text
        let selectedShapes = selectedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape
            }
            return nil
        }
        
        let selectedTexts = selectedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape
            }
            return nil
        }
        
        #expect(selectedShapes.count == 1)
        #expect(selectedTexts.count == 1)
        #expect(selectedShapes[0].name == "Selected Shape")
        #expect(selectedTexts[0].textContent == "Selected Text")
    }
}