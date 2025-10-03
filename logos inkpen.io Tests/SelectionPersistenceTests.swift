//
//  SelectionPersistenceTests.swift
//  logos inkpen.io Tests
//
//  Unit tests for verifying selection persistence during undo/redo operations
//

import XCTest
@testable import logos_inkpen_io

class SelectionPersistenceTests: XCTestCase {
    
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    // MARK: - Test Selection Encoding/Decoding
    
    func testSelectedObjectIDsPersistence() throws {
        // Create test objects
        let shape1 = VectorShape()
        shape1.id = UUID()
        let shape2 = VectorShape()
        shape2.id = UUID()
        
        let obj1 = VectorObject(objectType: .shape(shape1))
        let obj2 = VectorObject(objectType: .shape(shape2))
        
        document.unifiedObjects = [obj1, obj2]
        
        // Set up selections
        let selectedID1 = obj1.id
        let selectedID2 = obj2.id
        document.selectedObjectIDs = Set([selectedID1, selectedID2])
        document.selectedShapeIDs = Set([shape1.id, shape2.id])
        
        // Encode the document
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)
        
        // Decode into a new document
        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)
        
        // Verify selectedObjectIDs were preserved
        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 2, "selectedObjectIDs should have 2 items")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(selectedID1), "selectedObjectIDs should contain first object ID")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(selectedID2), "selectedObjectIDs should contain second object ID")
        
        // Verify selectedShapeIDs were preserved
        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 2, "selectedShapeIDs should have 2 items")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape1.id), "selectedShapeIDs should contain first shape ID")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape2.id), "selectedShapeIDs should contain second shape ID")
    }
    
    func testSelectionPreservedDuringUndoRedo() throws {
        // Create a shape and select it
        let shape = VectorShape()
        shape.id = UUID()
        let obj = VectorObject(objectType: .shape(shape))
        
        document.unifiedObjects = [obj]
        document.selectedObjectIDs = Set([obj.id])
        document.selectedShapeIDs = Set([shape.id])
        
        // Save initial state
        document.saveToUndoStack()
        
        // Move the shape (simulating user action)
        shape.position = CGPoint(x: 100, y: 100)
        document.selectedObjectIDs = Set([obj.id])  // Selection should remain
        document.selectedShapeIDs = Set([shape.id])
        document.saveToUndoStack()
        
        // Perform undo
        document.undo()
        
        // Verify selection is preserved after undo
        XCTAssertEqual(document.selectedObjectIDs.count, 1, "Selection should be preserved after undo")
        XCTAssertTrue(document.selectedObjectIDs.contains(obj.id), "Object should remain selected after undo")
        XCTAssertTrue(document.selectedShapeIDs.contains(shape.id), "Shape should remain selected after undo")
        
        // Verify position was restored
        XCTAssertEqual(shape.position, CGPoint.zero, "Shape position should be restored to original")
        
        // Perform redo
        document.redo()
        
        // Verify selection is preserved after redo
        XCTAssertEqual(document.selectedObjectIDs.count, 1, "Selection should be preserved after redo")
        XCTAssertTrue(document.selectedObjectIDs.contains(obj.id), "Object should remain selected after redo")
        XCTAssertTrue(document.selectedShapeIDs.contains(shape.id), "Shape should remain selected after redo")
        
        // Verify position was re-applied
        XCTAssertEqual(shape.position, CGPoint(x: 100, y: 100), "Shape position should be re-applied after redo")
    }
    
    func testEmptySelectionPersistence() throws {
        // Test that empty selections are also properly preserved
        document.selectedObjectIDs = Set()
        document.selectedShapeIDs = Set()
        document.selectedTextIDs = Set()
        
        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)
        
        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)
        
        // Verify empty selections are preserved
        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 0, "Empty selectedObjectIDs should be preserved")
        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 0, "Empty selectedShapeIDs should be preserved")
        XCTAssertEqual(decodedDocument.selectedTextIDs.count, 0, "Empty selectedTextIDs should be preserved")
    }
    
    func testMixedSelectionPersistence() throws {
        // Test with both shape and text selections
        let shape = VectorShape()
        shape.id = UUID()
        shape.isTextObject = false
        
        let textShape = VectorShape()
        textShape.id = UUID()
        textShape.isTextObject = true
        
        let obj1 = VectorObject(objectType: .shape(shape))
        let obj2 = VectorObject(objectType: .shape(textShape))
        
        document.unifiedObjects = [obj1, obj2]
        document.selectedObjectIDs = Set([obj1.id, obj2.id])
        document.selectedShapeIDs = Set([shape.id])
        document.selectedTextIDs = Set([textShape.id])
        
        // Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)
        
        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)
        
        // Verify all selection types are preserved
        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 2, "Both object selections should be preserved")
        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 1, "Shape selection should be preserved")
        XCTAssertEqual(decodedDocument.selectedTextIDs.count, 1, "Text selection should be preserved")
        
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(obj1.id), "First object should be selected")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(obj2.id), "Second object should be selected")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape.id), "Shape should be selected")
        XCTAssertTrue(decodedDocument.selectedTextIDs.contains(textShape.id), "Text should be selected")
    }
}