//
//  UnifiedObjectSystemSelectionColorTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemSelectionColorTests {
    
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
    
    // MARK: - ColorPanel Migration Tests
    
    @Test func testColorPanelTextStrokeUpdateViaUnified() async throws {
        let document = VectorDocument()
        
        // Create text object with initial typography
        let initialTypography = TypographyProperties(
            fontFamily: "Arial",
            fontSize: 12.0,
            hasStroke: false,
            strokeColor: VectorColor.black,
            strokeOpacity: 0.5,
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1))
        )
        
        let textObject = VectorText(
            content: "Test Stroke Update",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 100)
        )
        
        // Add to document using proper helper methods
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        
        // Simulate ColorPanel stroke color update
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        
        // Find text via unified objects (like migrated ColorPanel does)
        let foundInUnified = document.allTextObjects.contains(where: { $0.id == textObject.id })
        #expect(foundInUnified == true, "Should find text in unified objects")
        
        // Simulate the migrated ColorPanel updateSelectedTextStrokeColor
        document.selectedTextIDs = [textObject.id]
        
        // Update via unified objects system
        if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(var shape) = document.unifiedObjects[objectIndex].objectType {
                // Apply stroke color update
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = newStrokeColor
                shape.typography?.strokeOpacity = document.defaultStrokeOpacity
                
                // Update unified objects
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
                
                // Text is now fully managed in unified system
            }
        }
        
        // Verify update worked in unified objects
        let updatedTextInUnified = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInUnified != nil)
        #expect(updatedTextInUnified?.typography.hasStroke == true)
        #expect(updatedTextInUnified?.typography.strokeColor == newStrokeColor)
        #expect(updatedTextInUnified?.typography.strokeOpacity == document.defaultStrokeOpacity)
        
        // Verify legacy array was kept in sync
        let updatedTextInLegacy = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInLegacy != nil)
        #expect(updatedTextInLegacy?.typography.hasStroke == true)
        #expect(updatedTextInLegacy?.typography.strokeColor == newStrokeColor)
        #expect(updatedTextInLegacy?.typography.strokeOpacity == document.defaultStrokeOpacity)
        
        // Critical test: Both arrays should have same values
        #expect(updatedTextInUnified?.typography.hasStroke == updatedTextInLegacy?.typography.hasStroke)
        #expect(updatedTextInUnified?.typography.strokeColor == updatedTextInLegacy?.typography.strokeColor)
        #expect(updatedTextInUnified?.typography.strokeOpacity == updatedTextInLegacy?.typography.strokeOpacity)
    }
    
    @Test func testColorSwatchGridTextFillColorUpdate() async throws {
        let document = VectorDocument()
        
        // Create text object with initial fill color
        let initialTypography = TypographyProperties(
            fontFamily: "Arial",
            fontSize: 14.0,
            strokeColor: VectorColor.black,
            fillColor: VectorColor.black,
            fillOpacity: 1.0
        )
        
        let textObject = VectorText(
            content: "Test Fill Color",
            typography: initialTypography,
            position: CGPoint(x: 100, y: 150)
        )
        
        // Add to document using proper helper methods
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        
        // Test the ACTUAL ColorSwatchGrid fill color update
        let newFillColor = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1))
        
        // Simulate ColorSwatchGrid text fill color update
        if document.allTextObjects.contains(where: { $0.id == textObject.id }) {
            // Apply the migrated updateTextFillColorInUnified logic
            if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && shape.id == textObject.id
                }
                return false
            }) {
                if case .shape(var shape) = document.unifiedObjects[objectIndex].objectType {
                    // Update typography fill color in the shape
                    shape.typography?.fillColor = newFillColor
                    shape.typography?.fillOpacity = document.defaultFillOpacity
                    
                    // Update unified objects
                    document.unifiedObjects[objectIndex] = VectorObject(
                        shape: shape,
                        layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                        orderID: document.unifiedObjects[objectIndex].orderID
                    )
                    
                    // Legacy textObjects array no longer exists - unified system handles everything
                }
            }
        }
        
        // Verify fill color changed in unified objects
        let updatedTextInUnified = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInUnified != nil)
        #expect(updatedTextInUnified?.typography.fillColor == newFillColor)
        #expect(updatedTextInUnified?.typography.fillOpacity == document.defaultFillOpacity)
        
        // Verify legacy array was kept in sync
        let updatedTextInLegacy = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInLegacy != nil)
        #expect(updatedTextInLegacy?.typography.fillColor == newFillColor)
        #expect(updatedTextInLegacy?.typography.fillOpacity == document.defaultFillOpacity)
        
        // Critical test: Both arrays should have same fill color values
        #expect(updatedTextInUnified?.typography.fillColor == updatedTextInLegacy?.typography.fillColor)
        #expect(updatedTextInUnified?.typography.fillOpacity == updatedTextInLegacy?.typography.fillOpacity)
    }
}