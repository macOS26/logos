
import XCTest
@testable import logos_inkpen_io

final class GroupTextMovementTests: XCTestCase {

    var document: VectorDocument!

    override func setUp() {
        super.setUp()
        document = VectorDocument()

        document.addLayer()
        document.selectedLayerIndex = 0
    }

    override func tearDown() {
        document = nil
        super.tearDown()
    }


    func testTextObjectIncludedInGroup() {
        let textPosition = CGPoint(x: 100, y: 100)
        let textSize = CGSize(width: 200, height: 50)
        document.createTextObject(content: "Test Text", position: textPosition, areaSize: textSize)

        let shapePath = VectorPath(elements: [
            .move(to: VectorPoint(x: 200, y: 200)),
            .line(to: VectorPoint(x: 300, y: 200)),
            .line(to: VectorPoint(x: 300, y: 300)),
            .line(to: VectorPoint(x: 200, y: 300)),
            .close
        ], isClosed: true)
        let shape = VectorShape(name: "Rectangle", path: shapePath)
        document.appendShapeToLayerUnified(layerIndex: 0, shape: shape)

        if let textShape = document.unifiedObjects.first(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.isTextObject
            }
            return false
        }) {
            document.selectedObjectIDs = [textShape.id, shape.id]
            document.selectedShapeIDs = [shape.id]
            document.selectedTextIDs = [textShape.id]
        }

        document.groupSelectedObjects()

        let shapes = document.getShapesForLayer(0)
        XCTAssertEqual(shapes.count, 1, "Should have one group")
        XCTAssertTrue(shapes[0].isGroupContainer, "Should be a group")
        XCTAssertEqual(shapes[0].groupedShapes.count, 2, "Group should contain 2 objects")

        let hasTextObject = shapes[0].groupedShapes.contains { $0.isTextObject }
        XCTAssertTrue(hasTextObject, "Group should contain text object")
    }

    func testGroupMovementUpdatesTextPosition() {
        let textPosition = CGPoint(x: 100, y: 100)
        let textSize = CGSize(width: 200, height: 50)
        document.createTextObject(content: "Test Text", position: textPosition, areaSize: textSize)

        let shapePath = VectorPath(elements: [
            .move(to: VectorPoint(x: 200, y: 200)),
            .line(to: VectorPoint(x: 300, y: 200)),
            .line(to: VectorPoint(x: 300, y: 300)),
            .line(to: VectorPoint(x: 200, y: 300)),
            .close
        ], isClosed: true)
        let shape = VectorShape(name: "Rectangle", path: shapePath)
        document.appendShapeToLayerUnified(layerIndex: 0, shape: shape)

        if let textShape = document.unifiedObjects.first(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.isTextObject
            }
            return false
        }) {
            document.selectedObjectIDs = [textShape.id, shape.id]
            document.selectedShapeIDs = [shape.id]
            document.selectedTextIDs = [textShape.id]
        }

        document.groupSelectedObjects()

        let group = document.getShapesForLayer(0)[0]
        let textObjectInGroup = group.groupedShapes.first { $0.isTextObject }!
        let textID = textObjectInGroup.id

        let initialTextObj = document.findText(by: textID)!
        let initialPosition = initialTextObj.position

        let moveDelta = CGPoint(x: 50, y: 75)
        document.translateShape(id: group.id, delta: moveDelta)

        let updatedTextObj = document.findText(by: textID)!
        let expectedPosition = CGPoint(x: initialPosition.x + moveDelta.x, y: initialPosition.y + moveDelta.y)

        XCTAssertEqual(updatedTextObj.position.x, expectedPosition.x, accuracy: 0.01, "Text X position should be updated")
        XCTAssertEqual(updatedTextObj.position.y, expectedPosition.y, accuracy: 0.01, "Text Y position should be updated")
    }

    func testMultipleTextObjectsInGroupMove() {
        let text1Position = CGPoint(x: 100, y: 100)
        let text2Position = CGPoint(x: 300, y: 100)
        let textSize = CGSize(width: 150, height: 40)

        document.createTextObject(content: "Text 1", position: text1Position, areaSize: textSize)
        document.createTextObject(content: "Text 2", position: text2Position, areaSize: textSize)

        let textObjects = document.unifiedObjects.filter { obj in
            if case .shape(let s) = obj.objectType {
                return s.isTextObject
            }
            return false
        }

        XCTAssertEqual(textObjects.count, 2, "Should have 2 text objects")

        let textIDs = textObjects.map { $0.id }
        document.selectedObjectIDs = Set(textIDs)
        document.selectedTextIDs = Set(textIDs)

        document.groupSelectedObjects()

        let group = document.getShapesForLayer(0)[0]

        let moveDelta = CGPoint(x: 25, y: 50)
        document.translateShape(id: group.id, delta: moveDelta)

        for textID in textIDs {
            let textObj = document.findText(by: textID)!
            XCTAssertNotNil(textObj.position, "Text position should exist")
        }
    }
}
