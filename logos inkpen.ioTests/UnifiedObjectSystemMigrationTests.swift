//
//  UnifiedObjectSystemMigrationTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemMigrationTests {
    
    // MARK: - Migration Compatibility Tests
    
    @Test func testLegacyArraysStillPopulated() async throws {
        let document = VectorDocument()
        
        // Add text using helper method
        let text = VectorText(
            content: "Legacy Test",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black),
            position: CGPoint(x: 10, y: 20)
        )
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Add shape using helper method  
        let shape = VectorShape(name: "Legacy Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // Verify unified system has both test objects (plus background objects)
        #expect(document.unifiedObjects.count >= 2)
        
        // During migration, legacy arrays should still work
        // NOTE: This test will be updated as migration progresses
        // For now, just verify unified system is working
        let hasText = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.textContent == "Legacy Test"
            }
            return false
        }
        
        let hasShape = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.name == "Legacy Shape"
            }
            return false
        }
        
        #expect(hasText == true)
        #expect(hasShape == true)
    }
    
    @Test func testStrokeFillPanelFillColorMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "StrokeFillPanel Fill Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Test migration from StrokeFillPanel line 327 violation
        let newFillColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        document.updateTextFillColorInUnified(id: textObject.id, color: newFillColor)
        
        // Verify fill color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.fillColor == newFillColor)
    }
    
    @Test func testStrokeFillPanelStrokeColorMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "StrokeFillPanel Stroke Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Test migration from StrokeFillPanel line 458 violation
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0))
        document.updateTextStrokeColorInUnified(id: textObject.id, color: newStrokeColor)
        
        // Verify stroke color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.strokeColor == newStrokeColor)
        #expect(updatedText?.typography.hasStroke == true)
    }
    
    @Test func testColorPanelStrokeColorMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "ColorPanel Stroke Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedTextIDs.insert(textObject.id)
        
        // Test migration from ColorPanel line 449 violation
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 1, green: 0.5, blue: 0))
        document.updateTextStrokeColorInUnified(id: textObject.id, color: newStrokeColor)
        
        // Verify stroke color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.strokeColor == newStrokeColor)
        #expect(updatedText?.typography.hasStroke == true)
    }
    
    @Test func testColorSwatchGridStrokeColorMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "ColorSwatchGrid Stroke Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Test migration from ColorSwatchGrid line 371 violation
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 0.5, green: 0.5, blue: 1))
        document.updateTextStrokeColorInUnified(id: textObject.id, color: newStrokeColor)
        
        // Verify stroke color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.strokeColor == newStrokeColor)
        #expect(updatedText?.typography.hasStroke == true)
    }
    
    @Test func testVectorDocumentColorManagementFillMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "ColorManagement Fill Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Test migration from VectorDocument+ColorManagement line 102 violation
        let newFillColor = VectorColor.rgb(RGBColor(red: 1, green: 1, blue: 0))
        document.updateTextFillColorInUnified(id: textObject.id, color: newFillColor)
        
        // Verify fill color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.fillColor == newFillColor)
    }
    
    @Test func testVectorDocumentColorManagementStrokeMigration() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "ColorManagement Stroke Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 50)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.textObjects.append(textObject)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Test migration from VectorDocument+ColorManagement line 106 violation
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 1))
        document.updateTextStrokeColorInUnified(id: textObject.id, color: newStrokeColor)
        
        // Verify stroke color updated correctly
        let updatedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedText?.typography.strokeColor == newStrokeColor)
        #expect(updatedText?.typography.hasStroke == true)
    }
}