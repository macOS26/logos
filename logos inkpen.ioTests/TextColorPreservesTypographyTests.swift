//
//  TextColorPreservesTypographyTests.swift
//  logos inkpen.ioTests
//
//  CRITICAL: Tests to ensure changing text colors NEVER loses typography properties
//  This was a MAJOR BUG that reset font, size, weight, style when changing colors
//

import Testing
@testable import logos_inkpen_io
import SwiftUI

struct TextColorPreservesTypographyTests {
    
    @Test func testFillColorChangePreservesAllTypography() async throws {
        let document = VectorDocument()
        
        // Create text with CUSTOM typography settings
        let customTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold, 
            fontStyle: .italic,
            fontSize: 125.0,
            lineHeight: 130.0,
            lineSpacing: 2.5,
            letterSpacing: 0.0,
            alignment: .center,
            hasStroke: true,
            strokeColor: .black,
            strokeWidth: 3.0,
            strokeOpacity: 0.8,
            fillColor: VectorColor.rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)),
            fillOpacity: 0.9
        )
        
        let testText = VectorText(
            content: "CRITICAL TEST TEXT",
            typography: customTypography,
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Store original typography for comparison
        let originalFontFamily = customTypography.fontFamily
        let originalFontWeight = customTypography.fontWeight
        let originalFontStyle = customTypography.fontStyle
        let originalFontSize = customTypography.fontSize
        let originalAlignment = customTypography.alignment
        let originalLineSpacing = customTypography.lineSpacing
        let originalLineHeight = customTypography.lineHeight
        let originalStrokeWidth = customTypography.strokeWidth
        
        // CHANGE FILL COLOR
        let newColor = VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0))
        document.updateTextFillColorInUnified(id: testText.id, color: newColor)
        
        // GET THE TEXT BACK AND VERIFY ALL TYPOGRAPHY IS PRESERVED
        let updatedText = document.getTextByID(testText.id)
        #expect(updatedText != nil, "Text should still exist after color change")
        
        // CRITICAL CHECKS - These were being RESET before the fix!
        #expect(updatedText?.typography.fontFamily == originalFontFamily, 
                "Font family was LOST! Expected \(originalFontFamily), got \(updatedText?.typography.fontFamily ?? "nil")")
        #expect(updatedText?.typography.fontWeight == originalFontWeight,
                "Font weight was LOST! Expected \(originalFontWeight), got \(updatedText?.typography.fontWeight ?? .regular)")
        #expect(updatedText?.typography.fontStyle == originalFontStyle,
                "Font style was LOST! Expected \(originalFontStyle), got \(updatedText?.typography.fontStyle ?? .normal)")
        #expect(updatedText?.typography.fontSize == originalFontSize,
                "Font size was LOST! Expected \(originalFontSize), got \(updatedText?.typography.fontSize ?? 0)")
        #expect(updatedText?.typography.alignment == originalAlignment,
                "Text alignment was LOST!")
        #expect(updatedText?.typography.lineSpacing == originalLineSpacing,
                "Line spacing was LOST!")
        #expect(updatedText?.typography.lineHeight == originalLineHeight,
                "Line height was LOST!")
        #expect(updatedText?.typography.strokeWidth == originalStrokeWidth,
                "Stroke width was LOST!")
        
        // Verify color actually changed
        #expect(updatedText?.typography.fillColor == newColor, "Fill color should be updated")
        
        // Verify stroke properties preserved
        #expect(updatedText?.typography.hasStroke == true, "Stroke should still be enabled")
        #expect(updatedText?.typography.strokeColor == .black, "Stroke color should be preserved")
    }
    
    @Test func testStrokeColorChangePreservesAllTypography() async throws {
        let document = VectorDocument()
        
        // Create text with CUSTOM typography settings
        let customTypography = TypographyProperties(
            fontFamily: "Impact",
            fontWeight: .heavy,
            fontStyle: .normal, 
            fontSize: 72.5,
            lineHeight: 80.0,
            lineSpacing: 1.5,
            letterSpacing: 0.0,
            alignment: .right,
            hasStroke: false,
            strokeColor: .clear,
            strokeWidth: 0.0,
            strokeOpacity: 1.0,
            fillColor: VectorColor.rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0)),
            fillOpacity: 1.0
        )
        
        let testText = VectorText(
            content: "STROKE COLOR TEST",
            typography: customTypography,
            position: CGPoint(x: 200, y: 200)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(testText, layerIndex: 2)
        
        // Store original typography for comparison
        let originalFontFamily = customTypography.fontFamily
        let originalFontWeight = customTypography.fontWeight
        let originalFontStyle = customTypography.fontStyle
        let originalFontSize = customTypography.fontSize
        let originalAlignment = customTypography.alignment
        let originalFillColor = customTypography.fillColor
        
        // CHANGE STROKE COLOR
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0))
        document.updateTextStrokeColorInUnified(id: testText.id, color: newStrokeColor)
        
        // GET THE TEXT BACK AND VERIFY ALL TYPOGRAPHY IS PRESERVED
        let updatedText = document.getTextByID(testText.id)
        #expect(updatedText != nil, "Text should still exist after stroke color change")
        
        // CRITICAL CHECKS - Font properties MUST be preserved!
        #expect(updatedText?.typography.fontFamily == originalFontFamily,
                "Font family was LOST on stroke color change! Expected \(originalFontFamily), got \(updatedText?.typography.fontFamily ?? "nil")")
        #expect(updatedText?.typography.fontWeight == originalFontWeight,
                "Font weight was LOST on stroke color change!")
        #expect(updatedText?.typography.fontStyle == originalFontStyle,
                "Font style was LOST on stroke color change!")
        #expect(updatedText?.typography.fontSize == originalFontSize,
                "Font size was LOST on stroke color change! Expected \(originalFontSize), got \(updatedText?.typography.fontSize ?? 0)")
        #expect(updatedText?.typography.alignment == originalAlignment,
                "Text alignment was LOST on stroke color change!")
        
        // Verify stroke color actually changed
        #expect(updatedText?.typography.strokeColor == newStrokeColor, "Stroke color should be updated")
        #expect(updatedText?.typography.hasStroke == true, "Stroke should be enabled")
        
        // Verify fill color preserved
        #expect(updatedText?.typography.fillColor == originalFillColor, "Fill color should be preserved")
    }
    
    @Test func testMultipleColorChangesPreserveTypography() async throws {
        let document = VectorDocument()
        
        // Create text with very specific settings
        let testText = VectorText(
            content: "MULTIPLE CHANGES TEST",
            typography: TypographyProperties(
                fontFamily: "Zapfino",
                fontWeight: .regular,
                fontStyle: .normal,
                fontSize: 99.99,
                alignment: .justified,
                hasStroke: false,
                strokeColor: .clear,
                strokeWidth: 0.0,
                strokeOpacity: 1.0,
                fillColor: .black,
                fillOpacity: 1.0
            ),
            position: CGPoint(x: 300, y: 300)
        )
        
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Change fill color multiple times
        document.updateTextFillColorInUnified(id: testText.id, color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)))
        document.updateTextFillColorInUnified(id: testText.id, color: VectorColor.rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0)))
        document.updateTextFillColorInUnified(id: testText.id, color: VectorColor.rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)))
        
        // Change stroke color multiple times
        document.updateTextStrokeColorInUnified(id: testText.id, color: VectorColor.rgb(RGBColor(red: 1.0, green: 1.0, blue: 0.0)))
        document.updateTextStrokeColorInUnified(id: testText.id, color: VectorColor.rgb(RGBColor(red: 0.5, green: 0.0, blue: 0.5)))
        
        // Final check - ALL typography should still be intact
        let finalText = document.getTextByID(testText.id)
        #expect(finalText?.typography.fontFamily == "Zapfino",
                "Font family lost after multiple color changes!")
        #expect(finalText?.typography.fontSize == 99.99,
                "Font size lost after multiple color changes!")
        #expect(finalText?.typography.alignment == .justified,
                "Text alignment lost after multiple color changes!")
    }
}
