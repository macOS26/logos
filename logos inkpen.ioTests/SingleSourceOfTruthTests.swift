//
//  SingleSourceOfTruthTests.swift
//  logos inkpen.ioTests
//
//  Testing that unified objects is the single source of truth
//

import Testing
@testable import logos_inkpen_io
import Foundation
import CoreGraphics

@Suite("Single Source of Truth Tests")
struct SingleSourceOfTruthTests {
    
    @Test("Unified objects is the only source for shapes")
    func testUnifiedObjectsIsOnlySource() {
        let document = VectorDocument()
        
        // Add a shape through unified system
        let shape = VectorShape(
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(100, 0)),
                .line(to: VectorPoint(100, 100)),
                .line(to: VectorPoint(0, 100)),
                .close
            ])
        )
        document.addShape(shape, to: 0)
        
        // Verify shape exists in unified objects
        #expect(document.unifiedObjects.count > 0, "Shape should be in unified objects")
        
        // Verify we can get shapes for layer through helper
        let layerShapes = document.getShapesForLayer(0)
        #expect(layerShapes.count > 0, "Should get shapes through helper")
        #expect(layerShapes.first?.id == shape.id, "Should get correct shape")
        
        // After removing shapes array, this should work without layers[].shapes
        #expect(document.layers[0].name != "", "Layer should exist with metadata")
    }
    
    @Test("Text objects work through unified system")
    func testTextThroughUnifiedSystem() {
        let document = VectorDocument()
        
        // Add text
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 12,
                strokeColor: VectorColor.black,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 50, y: 50)
        )
        document.addTextToUnifiedSystem(text, layerIndex: 0)
        
        // Verify text is in unified objects
        let textInUnified = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == text.id
            }
            return false
        }
        #expect(textInUnified, "Text should be in unified objects")
        
        // Verify we can find text
        let foundText = document.findText(by: text.id)
        #expect(foundText != nil, "Should find text through unified system")
        #expect(foundText?.content == "Test", "Text content should match")
    }
}
