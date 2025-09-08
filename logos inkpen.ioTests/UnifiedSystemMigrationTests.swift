//
//  UnifiedSystemMigrationTests.swift
//  logos inkpen.ioTests
//
//  Comprehensive test suite for migrating from legacy arrays to unified system
//

import Testing
@testable import logos_inkpen_io
import Foundation
import CoreGraphics
import SwiftUI

@Suite("Unified System Migration Tests")
struct UnifiedSystemMigrationTests {
    
    // MARK: - Test Helpers
    
    private func createTestDocument() -> VectorDocument {
        let doc = VectorDocument(settings: DocumentSettings())
        
        // Add test shapes to layer 2 (default drawing layer)
        let shape1 = VectorShape(
            name: "Test Shape 1",
            path: VectorPath(elements: [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(100, 100))], isClosed: false),
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), opacity: 1.0)
        )
        
        let shape2 = VectorShape(
            name: "Test Shape 2",
            path: VectorPath(elements: [.move(to: VectorPoint(50, 50)), .line(to: VectorPoint(150, 150))], isClosed: false),
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)), opacity: 1.0)
        )
        
        // Add test text
        let text1 = VectorText(
            content: "Test Text 1",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 200, y: 200)
        )
        
        doc.addShape(shape1, to: 2)
        doc.addShape(shape2, to: 2)
        doc.addTextToUnifiedSystem(text1, layerIndex: 2)
        
        return doc
    }
    
    // MARK: - Selection State Tests
    
    @Test("Test isEmpty checks work with unified system")
    func testIsEmptyChecks() {
        let doc = createTestDocument()
        
        // Initial state - nothing selected
        #expect(doc.selectedObjectIDs.isEmpty)
        #expect(doc.selectedShapeIDs.isEmpty)
        #expect(doc.selectedTextIDs.isEmpty)
        
        // Select a shape
        let shapeID = doc.getShapesForLayer(2)[0].id
        doc.selectedObjectIDs.insert(shapeID)
        doc.syncSelectionArrays()
        
        #expect(!doc.selectedObjectIDs.isEmpty)
        #expect(!doc.selectedShapeIDs.isEmpty)
        #expect(doc.selectedTextIDs.isEmpty)
        
        // Clear and select text
        doc.selectedObjectIDs.removeAll()
        doc.syncSelectionArrays()
        
        let textID = doc.allTextObjects[0].id
        doc.selectedObjectIDs.insert(textID)
        doc.syncSelectionArrays()
        
        #expect(!doc.selectedObjectIDs.isEmpty)
        #expect(doc.selectedShapeIDs.isEmpty)
        #expect(!doc.selectedTextIDs.isEmpty)
    }
    
    @Test("Test count operations with unified system")
    func testCountOperations() {
        let doc = createTestDocument()
        
        // Select multiple shapes (excluding text shapes)
        for shape in doc.getShapesForLayer(2) where !shape.isTextObject {
            doc.selectedObjectIDs.insert(shape.id)
        }
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.count == 2)
        #expect(doc.selectedShapeIDs.count == 2)
        #expect(doc.selectedTextIDs.count == 0)
        
        // Add text to selection
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.count == 3)
        #expect(doc.selectedShapeIDs.count == 2)
        #expect(doc.selectedTextIDs.count == 1)
    }
    
    // MARK: - Selection Modification Tests
    
    @Test("Test insert operations with unified system")
    func testInsertOperations() {
        let doc = createTestDocument()
        let shapeID = doc.getShapesForLayer(2)[0].id
        
        // Old way
        doc.selectedShapeIDs.insert(shapeID)
        doc.syncUnifiedSelectionFromLegacy()
        
        #expect(doc.selectedObjectIDs.contains(shapeID))
        #expect(doc.selectedShapeIDs.contains(shapeID))
        
        // New unified way
        doc.selectedObjectIDs.removeAll()
        doc.selectedObjectIDs.insert(shapeID)
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.contains(shapeID))
        #expect(doc.selectedShapeIDs.contains(shapeID))
    }
    
    @Test("Test removeAll operations with unified system")
    func testRemoveAllOperations() {
        let doc = createTestDocument()
        
        // Select everything
        for shape in doc.getShapesForLayer(2) {
            doc.selectedObjectIDs.insert(shape.id)
        }
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.count == 3)
        
        // Old way - clear shape selection only
        doc.selectedShapeIDs.removeAll()
        doc.syncUnifiedSelectionFromLegacy()
        
        #expect(doc.selectedObjectIDs.count == 1) // Only text remains
        #expect(doc.selectedShapeIDs.isEmpty)
        #expect(!doc.selectedTextIDs.isEmpty)
        
        // New unified way - clear all
        doc.selectedObjectIDs.removeAll()
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.isEmpty)
        #expect(doc.selectedShapeIDs.isEmpty)
        #expect(doc.selectedTextIDs.isEmpty)
    }
    
    // MARK: - Iteration Pattern Tests
    
    @Test("Test iteration over selected shapes")
    func testShapeIteration() {
        let doc = createTestDocument()
        
        // Select all shapes
        for shape in doc.getShapesForLayer(2) {
            doc.selectedObjectIDs.insert(shape.id)
        }
        doc.syncSelectionArrays()
        
        // Old way - iterate selectedShapeIDs
        var oldWayCount = 0
        for shapeID in doc.selectedShapeIDs {
            if doc.getShapesForLayer(2).contains(where: { $0.id == shapeID }) {
                oldWayCount += 1
            }
        }
        #expect(oldWayCount == 2)
        
        // New unified way - filter by object type
        var newWayCount = 0
        for objectID in doc.selectedObjectIDs {
            if let object = doc.unifiedObjects.first(where: { $0.id == objectID }) {
                switch object.objectType {
                case .shape(let shape):
                    if !shape.isTextObject {
                        newWayCount += 1
                    }
                }
            }
        }
        #expect(newWayCount == 2)
    }
    
    @Test("Test getSelectedShapes helper")
    func testGetSelectedShapes() {
        let doc = createTestDocument()
        
        // Select one shape and one text
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        let selectedShapes = doc.getSelectedShapes()
        #expect(selectedShapes.count == 1)
        #expect(selectedShapes[0].id == doc.getShapesForLayer(2)[0].id)
    }
    
    // MARK: - Complex Selection Logic Tests
    
    @Test("Test combined isEmpty checks")
    func testCombinedIsEmptyChecks() {
        let doc = createTestDocument()
        
        // Check: selectedShapeIDs.isEmpty && selectedTextIDs.isEmpty
        // Should be equivalent to: selectedObjectIDs.isEmpty
        
        #expect(doc.selectedShapeIDs.isEmpty && doc.selectedTextIDs.isEmpty)
        #expect(doc.selectedObjectIDs.isEmpty)
        
        // Select a shape
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.syncSelectionArrays()
        
        #expect(!(doc.selectedShapeIDs.isEmpty && doc.selectedTextIDs.isEmpty))
        #expect(!doc.selectedObjectIDs.isEmpty)
        
        // Clear and select text
        doc.selectedObjectIDs.removeAll()
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        #expect(!(doc.selectedShapeIDs.isEmpty && doc.selectedTextIDs.isEmpty))
        #expect(!doc.selectedObjectIDs.isEmpty)
    }
    
    @Test("Test OR logic checks")
    func testOrLogicChecks() {
        let doc = createTestDocument()
        
        // Check: !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty
        // Should be equivalent to: !selectedObjectIDs.isEmpty
        
        #expect(!(!(doc.selectedShapeIDs.isEmpty) || !(doc.selectedTextIDs.isEmpty)))
        #expect(doc.selectedObjectIDs.isEmpty)
        
        // Select shape
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.syncSelectionArrays()
        
        #expect(!doc.selectedShapeIDs.isEmpty || !doc.selectedTextIDs.isEmpty)
        #expect(!doc.selectedObjectIDs.isEmpty)
    }
    
    // MARK: - Menu Command Tests
    
    @Test("Test duplicate operation selection")
    func testDuplicateSelection() {
        let doc = createTestDocument()
        
        // Test shape duplication
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.syncSelectionArrays()
        
        // Old check: !selectedShapeIDs.isEmpty
        #expect(!doc.selectedShapeIDs.isEmpty)
        
        // New unified check
        let hasShapeSelection = doc.selectedObjectIDs.contains { id in
            doc.unifiedObjects.first { $0.id == id }?.objectType == .shape(doc.getShapesForLayer(2)[0])
        }
        #expect(hasShapeSelection)
        
        // Test text duplication
        doc.selectedObjectIDs.removeAll()
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        // Old check: !selectedTextIDs.isEmpty
        #expect(!doc.selectedTextIDs.isEmpty)
        
        // New unified check for text
        let hasTextSelection = doc.selectedObjectIDs.contains { id in
            doc.getTextByID(id) != nil
        }
        #expect(hasTextSelection)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test selection performance with many objects")
    func testSelectionPerformance() {
        let doc = VectorDocument(settings: DocumentSettings())
        
        // Add 100 shapes
        for i in 0..<100 {
            let shape = VectorShape(
                name: "Shape \(i)",
                path: VectorPath(elements: [.move(to: VectorPoint(Double(i), Double(i)))], isClosed: false),
                strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
                fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), opacity: 1.0)
            )
            doc.addShape(shape, to: 2)
        }
        
        // Measure old way
        let startOld = Foundation.Date()
        for shape in doc.getShapesForLayer(2) {
            doc.selectedShapeIDs.insert(shape.id)
        }
        doc.syncSelectionArrays()
        let oldTime = Foundation.Date().timeIntervalSince(startOld)
        
        // Clear
        doc.selectedObjectIDs.removeAll()
        doc.selectedShapeIDs.removeAll()
        doc.syncSelectionArrays()
        
        // Measure new unified way
        let startNew = Foundation.Date()
        for shape in doc.getShapesForLayer(2) {
            doc.selectedObjectIDs.insert(shape.id)
        }
        doc.syncSelectionArrays()
        let newTime = Foundation.Date().timeIntervalSince(startNew)
        
        // Unified should be comparable or faster
        print("Old way: \(oldTime)s, New way: \(newTime)s")
        #expect(doc.selectedObjectIDs.count == 100)
        #expect(doc.selectedShapeIDs.count == 100)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Test selection with deleted objects")
    func testSelectionWithDeletedObjects() {
        let doc = createTestDocument()
        let shapeID = doc.getShapesForLayer(2)[0].id
        
        // Select shape
        doc.selectedObjectIDs.insert(shapeID)
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.contains(shapeID))
        
        // Remove shape from layer but not from selection
        doc.getShapesForLayer(2).removeAll { $0.id == shapeID }
        doc.populateUnifiedObjectsFromLayersPreservingOrder()
        
        // Unified system should handle orphaned selections gracefully
        #expect(doc.selectedObjectIDs.contains(shapeID)) // Still in selection
        #expect(!doc.unifiedObjects.contains { $0.id == shapeID }) // But not in unified objects
    }
    
    @Test("Test selection across layers")
    func testCrossLayerSelection() {
        let doc = createTestDocument()
        
        // Add shape to different layer
        let shape3 = VectorShape(
            name: "Layer 3 Shape",
            path: VectorPath(elements: [.move(to: VectorPoint(0, 0))], isClosed: false),
            strokeStyle: StrokeStyle(color: .black, width: 1.0, placement: .center, opacity: 1.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 1, blue: 0, alpha: 1)), opacity: 1.0)
        )
        
        // Add new layer if needed
        if doc.layers.count <= 3 {
            doc.layers.append(VectorLayer(name: "Layer 3"))
        }
        doc.addShape(shape3, to: 3)
        
        // Select shapes from different layers
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.selectedObjectIDs.insert(shape3.id)
        doc.syncSelectionArrays()
        
        #expect(doc.selectedObjectIDs.count == 2)
        #expect(doc.selectedShapeIDs.count == 2)
        
        // Verify unified system tracks layer indices correctly
        let objects = doc.unifiedObjects.filter { doc.selectedObjectIDs.contains($0.id) }
        let layerIndices = Set(objects.map { $0.layerIndex })
        #expect(layerIndices.count == 2) // Should have objects from 2 layers
    }
    
    // MARK: - FontPanel Specific Tests
    
    @Test("Test FontPanel text selection checks")
    func testFontPanelTextSelection() {
        let doc = createTestDocument()
        
        // No text selected
        #expect(doc.selectedTextIDs.isEmpty)
        
        // Select text
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        #expect(!doc.selectedTextIDs.isEmpty)
        #expect(doc.selectedTextIDs.count == 1)
        
        // FontPanel uses selectedTextIDs.first frequently
        let firstTextID = doc.selectedTextIDs.first
        #expect(firstTextID != nil)
        #expect(firstTextID == doc.allTextObjects[0].id)
        
        // Verify text object retrieval
        if let textID = firstTextID {
            let textObject = doc.allTextObjects.first { $0.id == textID }
            #expect(textObject != nil)
            #expect(textObject?.content == "Test Text 1")
        }
    }
    
    // MARK: - File Operation Tests
    
    @Test("Test selection preservation during save/load")
    func testSelectionPersistence() throws {
        let doc = createTestDocument()
        
        // Select mixed objects
        doc.selectedObjectIDs.insert(doc.getShapesForLayer(2)[0].id)
        doc.selectedObjectIDs.insert(doc.allTextObjects[0].id)
        doc.syncSelectionArrays()
        
        let originalShapeIDs = doc.selectedShapeIDs
        let originalTextIDs = doc.selectedTextIDs
        let originalObjectIDs = doc.selectedObjectIDs
        
        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)
        
        let decoder = JSONDecoder()
        let loadedDoc = try decoder.decode(VectorDocument.self, from: data)
        
        // Verify selection restored correctly
        #expect(loadedDoc.selectedShapeIDs == originalShapeIDs)
        #expect(loadedDoc.selectedTextIDs == originalTextIDs)
        
        // selectedObjectIDs needs to be rebuilt from legacy arrays after loading
        loadedDoc.syncUnifiedSelectionFromLegacy()
        #expect(loadedDoc.selectedObjectIDs == originalObjectIDs)
    }
}
