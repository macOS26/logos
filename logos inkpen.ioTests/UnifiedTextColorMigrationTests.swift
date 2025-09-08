//
//  UnifiedTextColorMigrationTests.swift
//  logos inkpen.ioTests
//
//  Testing migration of updateTextFillColorInUnified to use unified objects system
//

import Testing
@testable import logos_inkpen_io
import Foundation
import CoreGraphics

@Suite("Unified Text Color Migration Tests")
struct UnifiedTextColorMigrationTests {
    
    @Test("updateTextFillColorInUnified preserves font and updates color")
    func testUpdateTextFillColorPreservesTypography() {
        let document = VectorDocument()
        
        // Create a text object with specific typography
        let textObject = VectorText(
            content: "Test Text",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                alignment: TextAlignment.center,
                strokeColor: VectorColor.black,
                fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0)),
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add text through unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        // Verify initial state
        if let addedText = document.findText(by: textObject.id) {
            #expect(addedText.typography.fontFamily == "Helvetica")
            #expect(addedText.typography.fontSize == 24)
            #expect(addedText.typography.fontWeight == FontWeight.bold)
            #expect(addedText.typography.fontStyle == FontStyle.italic)
            #expect(addedText.typography.alignment == TextAlignment.center)
        } else {
            Issue.record("Text not found after adding")
        }
        
        // Update color using the method
        let newColor = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1))
        document.updateTextFillColorInUnified(id: textObject.id, color: newColor)
        
        // Verify font is preserved and color is updated
        if let updatedText = document.findText(by: textObject.id) {
            #expect(updatedText.typography.fontFamily == "Helvetica", "Font family should be preserved")
            #expect(updatedText.typography.fontSize == 24, "Font size should be preserved")
            #expect(updatedText.typography.fontWeight == FontWeight.bold, "Font weight should be preserved")
            #expect(updatedText.typography.fontStyle == FontStyle.italic, "Font style should be preserved")
            #expect(updatedText.typography.alignment == TextAlignment.center, "Alignment should be preserved")
            
            // Verify color was updated
            if case .rgb(let rgbColor) = updatedText.typography.fillColor {
                #expect(rgbColor.red == 0, "Red should be 0")
                #expect(rgbColor.green == 0, "Green should be 0")
                #expect(rgbColor.blue == 1, "Blue should be 1")
            } else {
                Issue.record("Fill color is not RGB")
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
            #expect(unified.typography?.fontWeight == FontWeight.bold, "Unified typography should preserve weight")
        }
    }
    
    @Test("updateTextFillColorInUnified works with various colors")
    func testUpdateTextFillColorVariousColors() {
        let document = VectorDocument()
        
        let textObject = VectorText(
            content: "Color Test",
            typography: TypographyProperties(
                strokeColor: VectorColor.black,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 50, y: 50)
        )
        
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        // Test updating to green
        let newColor = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0))
        document.updateTextFillColorInUnified(id: textObject.id, color: newColor)
        
        if let updatedText = document.findText(by: textObject.id) {
            if case .rgb(let rgbColor) = updatedText.typography.fillColor {
                #expect(rgbColor.green == 1, "Green should be 1")
            }
        } else {
            Issue.record("Text not found after color update")
        }
    }
}