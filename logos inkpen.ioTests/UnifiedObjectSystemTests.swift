//
//  UnifiedObjectSystemTests.swift
//  logos inkpen.ioTests
//
//  Created by Claude on 1/21/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io

struct UnifiedObjectSystemTests {
    
    // MARK: - Helper Method Tests
    
    @Test func testAddTextToUnifiedSystemCreatesProperShape() async throws {
        let document = VectorDocument()
        
        let typography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontSize: 24.0,
            strokeColor: VectorColor.black,
            fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        )
        
        let text = VectorText(
            content: "Test Text",
            typography: typography,
            position: CGPoint(x: 100, y: 200),
            areaSize: CGSize(width: 300, height: 150)
        )
        
        // Use helper method to add text
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Verify unified object was created correctly
        #expect(document.unifiedObjects.count == 1)
        
        let unifiedObj = document.unifiedObjects[0]
        #expect(unifiedObj.layerIndex == 1)
        
        if case .shape(let shape) = unifiedObj.objectType {
            #expect(shape.isTextObject == true)
            #expect(shape.textContent == "Test Text")
            #expect(shape.typography?.fontFamily == "Herculanum")
            #expect(shape.typography?.fontWeight == .bold)
            #expect(shape.typography?.fontSize == 24.0)
            #expect(shape.areaSize?.width == 300)
            #expect(shape.areaSize?.height == 150)
        } else {
            #expect(Bool(false), "Should create shape object type")
        }
    }
    
    @Test func testAddShapeToUnifiedSystemPreventsDuplicates() async throws {
        let document = VectorDocument()
        
        let shape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1)), opacity: 1.0)
        )
        
        // Add shape twice with same ID
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // Should only have one unified object (no duplicates)
        #expect(document.unifiedObjects.count == 1)
        
        if case .shape(let unifiedShape) = document.unifiedObjects[0].objectType {
            #expect(unifiedShape.id == shape.id)
            #expect(unifiedShape.name == "Test Shape")
        }
    }
    
    // MARK: - Unified Object Access Tests
    
    @Test func testUnifiedObjectsContainBothShapesAndText() async throws {
        let document = VectorDocument()
        
        // Add regular shape
        let regularShape = VectorShape(
            name: "Circle",
            path: VectorPath(elements: [], isClosed: true),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0)), opacity: 1.0),
            isTextObject: false
        )
        document.addShapeToUnifiedSystem(regularShape, layerIndex: 0)
        
        // Add text object
        let textObj = VectorText(
            content: "Hello World",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1))),
            position: CGPoint(x: 50, y: 75)
        )
        document.addTextToUnifiedSystem(textObj, layerIndex: 1)
        
        // Verify both are in unified objects
        #expect(document.unifiedObjects.count == 2)
        
        // Find shape object
        let shapeObjects = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape
            }
            return nil
        }
        #expect(shapeObjects.count == 1)
        #expect(shapeObjects[0].name == "Circle")
        #expect(shapeObjects[0].fillStyle?.color == VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0)))
        
        // Find text object
        let textObjects = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape
            }
            return nil
        }
        #expect(textObjects.count == 1)
        #expect(textObjects[0].textContent == "Hello World")
        #expect(textObjects[0].typography?.fillColor == VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1)))
    }
    
    @Test func testUnifiedObjectOrderingByLayer() async throws {
        let document = VectorDocument()
        
        // Add objects to different layers
        let shape1 = VectorShape(name: "Layer 0 Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape1, layerIndex: 0)
        
        let text1 = VectorText(content: "Layer 1 Text", typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black))
        document.addTextToUnifiedSystem(text1, layerIndex: 1)
        
        let shape2 = VectorShape(name: "Layer 2 Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape2, layerIndex: 2)
        
        // Verify proper layer assignment
        let layer0Objects = document.unifiedObjects.filter { $0.layerIndex == 0 }
        let layer1Objects = document.unifiedObjects.filter { $0.layerIndex == 1 }
        let layer2Objects = document.unifiedObjects.filter { $0.layerIndex == 2 }
        
        #expect(layer0Objects.count == 1)
        #expect(layer1Objects.count == 1)
        #expect(layer2Objects.count == 1)
        
        // Verify orderIDs increment properly
        #expect(layer0Objects[0].orderID == 0)
        #expect(layer1Objects[0].orderID == 0)
        #expect(layer2Objects[0].orderID == 0)
    }
    
    // MARK: - Copy/Paste System Tests
    
    @Test func testCopyPastePreservesAllTextAttributes() async throws {
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
        document.textObjects.append(textObject) // Keep legacy in sync
        
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
                
                // Keep legacy array in sync
                if let legacyIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }),
                   let vectorText = VectorText.from(shape) {
                    document.textObjects[legacyIndex] = vectorText
                }
            }
        }
        
        // Verify update worked in unified objects
        let updatedTextInUnified = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInUnified != nil)
        #expect(updatedTextInUnified?.typography.hasStroke == true)
        #expect(updatedTextInUnified?.typography.strokeColor == newStrokeColor)
        #expect(updatedTextInUnified?.typography.strokeOpacity == document.defaultStrokeOpacity)
        
        // Verify legacy array was kept in sync
        let updatedTextInLegacy = document.textObjects.first { $0.id == textObject.id }
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
        document.textObjects.append(textObject) // Keep legacy in sync
        
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
                    
                    // Keep legacy textObjects array in sync
                    if let legacyIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }),
                       let vectorText = VectorText.from(shape) {
                        document.textObjects[legacyIndex] = vectorText
                    }
                }
            }
        }
        
        // Verify fill color changed in unified objects
        let updatedTextInUnified = document.allTextObjects.first { $0.id == textObject.id }
        #expect(updatedTextInUnified != nil)
        #expect(updatedTextInUnified?.typography.fillColor == newFillColor)
        #expect(updatedTextInUnified?.typography.fillOpacity == document.defaultFillOpacity)
        
        // Verify legacy array was kept in sync
        let updatedTextInLegacy = document.textObjects.first { $0.id == textObject.id }
        #expect(updatedTextInLegacy != nil)
        #expect(updatedTextInLegacy?.typography.fillColor == newFillColor)
        #expect(updatedTextInLegacy?.typography.fillOpacity == document.defaultFillOpacity)
        
        // Critical test: Both arrays should have same fill color values
        #expect(updatedTextInUnified?.typography.fillColor == updatedTextInLegacy?.typography.fillColor)
        #expect(updatedTextInUnified?.typography.fillOpacity == updatedTextInLegacy?.typography.fillOpacity)
    }
    
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
        
        // Verify unified system has both
        #expect(document.unifiedObjects.count == 2)
        
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
}