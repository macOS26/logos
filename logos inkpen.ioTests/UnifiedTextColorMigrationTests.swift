//
//  UnifiedTextColorMigrationTests.swift
//  logos inkpen.ioTests
//
//  Testing migration of updateTextFillColorInUnified to eliminate layers[].shapes
//

import Testing
@testable import logos_inkpen_io
import Foundation
import CoreGraphics

@Suite("Unified Text Color Migration Tests")
struct UnifiedTextColorMigrationTests {
    
    @Test("updateTextFillColorInUnified preserves font and updates color")
    func testUpdateTextFillColorPreservesFont() {
        let document = VectorDocument()
        
        // Create a text object with specific typography
        let textObject = VectorText(
            content: "Test Text",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .bold,
                fontStyle: .italic,
                alignment: .center,
                fillColor: .solid(color: CGColor(red: 1, green: 0, blue: 0, alpha: 1)),
                fillOpacity: 1.0
            )
        )
        
        // Add text through unified system
        document.addText(textObject, to: 0)
        
        // Verify initial state
        if let addedText = document.findText(by: textObject.id) {
            #expect(addedText.typography.fontFamily == "Helvetica")
            #expect(addedText.typography.fontSize == 24)
            #expect(addedText.typography.fontWeight == .bold)
            #expect(addedText.typography.fontStyle == .italic)
            #expect(addedText.typography.alignment == .center)
        } else {
            Issue.record("Text not found after adding")
        }
        
        // Update color using the method
        let newColor = VectorColor.solid(color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        document.updateTextFillColorInUnified(id: textObject.id, color: newColor)
        
        // Verify font is preserved and color is updated
        if let updatedText = document.findText(by: textObject.id) {
            #expect(updatedText.typography.fontFamily == "Helvetica", "Font family should be preserved")
            #expect(updatedText.typography.fontSize == 24, "Font size should be preserved")
            #expect(updatedText.typography.fontWeight == .bold, "Font weight should be preserved")
            #expect(updatedText.typography.fontStyle == .italic, "Font style should be preserved")
            #expect(updatedText.typography.alignment == .center, "Alignment should be preserved")
            
            // Verify color was updated
            if case .solid(let color) = updatedText.typography.fillColor {
                let components = color.components ?? []
                #expect(components.count >= 3)
                if components.count >= 3 {
                    #expect(components[0] == 0, "Red should be 0")
                    #expect(components[1] == 0, "Green should be 0")
                    #expect(components[2] == 1, "Blue should be 1")
                }
            } else {
                Issue.record("Fill color is not solid")
            }
        } else {
            Issue.record("Text not found after color update")
        }
        
        // Verify unified objects are in sync
        let unifiedText = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.id == textObject.id {
                return shape
            }
            return nil
        }.first
        
        #expect(unifiedText != nil, "Text should exist in unified objects")
        if let unified = unifiedText {
            #expect(unified.typography?.fontFamily == "Helvetica", "Unified typography should preserve font")
            #expect(unified.typography?.fontSize == 24, "Unified typography should preserve size")
            #expect(unified.typography?.fontWeight == .bold, "Unified typography should preserve weight")
            #expect(unified.typography?.fontStyle == .italic, "Unified typography should preserve style")
        }
    }
    
    @Test("updateTextFillColorInUnified handles nil typography")
    func testUpdateTextFillColorHandlesNilTypography() {
        let document = VectorDocument()
        
        // Create text with minimal typography
        let textObject = VectorText(
            content: "Test",
            position: CGPoint(x: 50, y: 50)
        )
        
        document.addText(textObject, to: 0)
        
        // Update color
        let newColor = VectorColor.solid(color: CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        document.updateTextFillColorInUnified(id: textObject.id, color: newColor)
        
        // Verify text still exists and has color
        if let updatedText = document.findText(by: textObject.id) {
            if case .solid(let color) = updatedText.typography.fillColor {
                let components = color.components ?? []
                if components.count >= 3 {
                    #expect(components[1] == 1, "Green should be 1")
                }
            }
        } else {
            Issue.record("Text not found after color update")
        }
    }
}
