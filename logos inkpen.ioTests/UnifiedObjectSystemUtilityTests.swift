//
//  UnifiedObjectSystemUtilityTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemUtilityTests {
    
    @Test func testStrokeFillPanelMigration() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Panel Test",
            typography: TypographyProperties(
                strokeColor: VectorColor.black,
                strokeWidth: 1.0, fillColor: VectorColor.black,
                fillOpacity: 0.5
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Add to unified system (text is now stored as shapes)
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        document.selectedObjectIDs.insert(testText.id)
        
        // Test opacity update like StrokeFillPanel does
        document.updateTextFillOpacityInUnified(id: testText.id, opacity: 0.9)
        
        // Test stroke width update like StrokeFillPanel does
        document.updateTextStrokeWidthInUnified(id: testText.id, width: 2.5)
        
        // Verify updates worked
        let updatedText = document.getTextByID(testText.id)
        #expect(updatedText?.typography.fillOpacity == 0.9, "Fill opacity migration failed")
        #expect(updatedText?.typography.strokeWidth == 2.5, "Stroke width migration failed")
    }
    
    @Test func testTranslateTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let originalPosition = CGPoint(x: 100, y: 200)
        let testText = VectorText(
            content: "Position Test",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: originalPosition
        )
        
        // Add to unified system (text is now stored as shapes)
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Use unified helper to translate
        let delta = CGPoint(x: 50, y: -30)
        document.translateTextInUnified(id: testText.id, delta: delta)
        
        // Verify both arrays updated
        let expectedPosition = CGPoint(x: 150, y: 170)
        let updatedText = document.getTextByID(testText.id)
        #expect(updatedText?.position == expectedPosition, "Legacy textObjects position not updated")
        
        let updatedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        if case .shape(let shape) = updatedUnifiedShape?.objectType {
            #expect(shape.transform.tx == 150, "Unified objects transform.tx not updated")
            #expect(shape.transform.ty == 170, "Unified objects transform.ty not updated")
        }
    }
    
    @Test func testTranslateAllTextInUnified() async throws {
        let document = VectorDocument()
        
        // Create multiple test texts
        let text1 = VectorText(
            content: "Text 1",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100)
        )
        let text2 = VectorText(
            content: "Text 2",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 200, y: 300)
        )
        
        // Add to unified system (text is now stored as shapes)
        document.addTextToUnifiedSystem(text1, layerIndex: 1)
        document.addTextToUnifiedSystem(text2, layerIndex: 1)
        
        // Use unified helper to translate all
        let delta = CGPoint(x: 25, y: -50)
        document.translateAllTextInUnified(delta: delta)
        
        // Verify all texts updated
        let updatedText1 = document.getTextByID(text1.id)
        let updatedText2 = document.getTextByID(text2.id)
        
        #expect(updatedText1?.position == CGPoint(x: 125, y: 50), "Text 1 position not updated")
        #expect(updatedText2?.position == CGPoint(x: 225, y: 250), "Text 2 position not updated")
    }
    
    @Test func testUpdateTextLayerInUnified() async throws {
        let document = VectorDocument()
        
        // Create test text
        let testText = VectorText(
            content: "Layer Test",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 100, y: 100),
            layerIndex: 1
        )
        
        // Add to unified system (text is now stored as shapes)
        document.addTextToUnifiedSystem(testText, layerIndex: 1)
        
        // Verify initial layer
        #expect(document.textObjects.first?.layerIndex == 1)
        let initialUnified = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(initialUnified?.layerIndex == 1)
        
        // Use unified helper to update layer
        document.updateTextLayerInUnified(id: testText.id, layerIndex: 3)
        
        // Verify both arrays updated
        let updatedText = document.getTextByID(testText.id)
        #expect(updatedText?.layerIndex == 3, "Legacy textObjects layerIndex not updated")
        
        let updatedUnified = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == testText.id
            }
            return false
        }
        #expect(updatedUnified?.layerIndex == 3, "Unified objects layerIndex not updated")
    }
    
}