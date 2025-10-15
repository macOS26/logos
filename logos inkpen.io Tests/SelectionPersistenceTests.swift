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

    func testSelectedObjectIDsPersistence() throws {
        let shape1 = VectorShape()
        shape1.id = UUID()
        let shape2 = VectorShape()
        shape2.id = UUID()

        let obj1 = VectorObject(objectType: .shape(shape1))
        let obj2 = VectorObject(objectType: .shape(shape2))

        document.unifiedObjects = [obj1, obj2]

        let selectedID1 = obj1.id
        let selectedID2 = obj2.id
        document.selectedObjectIDs = Set([selectedID1, selectedID2])
        document.selectedShapeIDs = Set([shape1.id, shape2.id])

        let encoder = JSONEncoder()
        let data = try encoder.encode(document)

        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)

        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 2, "selectedObjectIDs should have 2 items")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(selectedID1), "selectedObjectIDs should contain first object ID")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(selectedID2), "selectedObjectIDs should contain second object ID")

        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 2, "selectedShapeIDs should have 2 items")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape1.id), "selectedShapeIDs should contain first shape ID")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape2.id), "selectedShapeIDs should contain second shape ID")
    }

    func testSelectionPreservedDuringUndoRedo() throws {
        let shape = VectorShape()
        shape.id = UUID()
        let obj = VectorObject(objectType: .shape(shape))

        document.unifiedObjects = [obj]
        document.selectedObjectIDs = Set([obj.id])
        document.selectedShapeIDs = Set([shape.id])

        document.saveToUndoStack()

        shape.position = CGPoint(x: 100, y: 100)
        document.selectedObjectIDs = Set([obj.id])
        document.selectedShapeIDs = Set([shape.id])
        document.saveToUndoStack()

        document.undo()

        XCTAssertEqual(document.selectedObjectIDs.count, 1, "Selection should be preserved after undo")
        XCTAssertTrue(document.selectedObjectIDs.contains(obj.id), "Object should remain selected after undo")
        XCTAssertTrue(document.selectedShapeIDs.contains(shape.id), "Shape should remain selected after undo")

        XCTAssertEqual(shape.position, CGPoint.zero, "Shape position should be restored to original")

        document.redo()

        XCTAssertEqual(document.selectedObjectIDs.count, 1, "Selection should be preserved after redo")
        XCTAssertTrue(document.selectedObjectIDs.contains(obj.id), "Object should remain selected after redo")
        XCTAssertTrue(document.selectedShapeIDs.contains(shape.id), "Shape should remain selected after redo")

        XCTAssertEqual(shape.position, CGPoint(x: 100, y: 100), "Shape position should be re-applied after redo")
    }

    func testEmptySelectionPersistence() throws {
        document.selectedObjectIDs = Set()
        document.selectedShapeIDs = Set()
        document.selectedTextIDs = Set()

        let encoder = JSONEncoder()
        let data = try encoder.encode(document)

        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)

        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 0, "Empty selectedObjectIDs should be preserved")
        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 0, "Empty selectedShapeIDs should be preserved")
        XCTAssertEqual(decodedDocument.selectedTextIDs.count, 0, "Empty selectedTextIDs should be preserved")
    }

    func testMixedSelectionPersistence() throws {
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

        let encoder = JSONEncoder()
        let data = try encoder.encode(document)

        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(VectorDocument.self, from: data)

        XCTAssertEqual(decodedDocument.selectedObjectIDs.count, 2, "Both object selections should be preserved")
        XCTAssertEqual(decodedDocument.selectedShapeIDs.count, 1, "Shape selection should be preserved")
        XCTAssertEqual(decodedDocument.selectedTextIDs.count, 1, "Text selection should be preserved")

        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(obj1.id), "First object should be selected")
        XCTAssertTrue(decodedDocument.selectedObjectIDs.contains(obj2.id), "Second object should be selected")
        XCTAssertTrue(decodedDocument.selectedShapeIDs.contains(shape.id), "Shape should be selected")
        XCTAssertTrue(decodedDocument.selectedTextIDs.contains(textShape.id), "Text should be selected")
    }
}
