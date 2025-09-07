//
//  UnifiedObjectSystemCriticalTests.swift
//  logos inkpen.ioTests
//
//  CRITICAL TEMPORAL STABILITY TESTS
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemCriticalTests {
    
    @Test func testPathUpdateUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newPath = VectorPath(elements: [.move(to: VectorPoint(10, 10)), .line(to: VectorPoint(60, 60))], isClosed: false)
        document.updateShapePathUnified(id: shape.id, path: newPath)
        
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.path.elements.count == 2, "Path not updated")
    }
    
    @Test func testLockUnlockUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        document.lockShapeInUnified(id: shape.id)
        let lockedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(lockedShape?.isLocked == true, "Shape not locked")
        
        document.unlockShapeInUnified(id: shape.id)
        let unlockedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(unlockedShape?.isLocked == false, "Shape not unlocked")
    }
    
    @Test func testVisibilityUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        document.hideShapeInUnified(id: shape.id)
        let hiddenShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(hiddenShape?.isVisible == false, "Shape not hidden")
        
        document.showShapeInUnified(id: shape.id)
        let visibleShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(visibleShape?.isVisible == true, "Shape not shown")
    }
    
    @Test func testUnifiedSystemSync() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let initialUnifiedCount = document.unifiedObjects.count
        let initialLayerShapeCount = document.layers[0].shapes.count
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        #expect(document.unifiedObjects.count == initialUnifiedCount + 1, "Unified object not added")
        #expect(document.layers[0].shapes.count == initialLayerShapeCount + 1, "Legacy shape not added")
        
        let addedUnifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == shape.id
            }
            return false
        }
        #expect(addedUnifiedShape != nil, "Unified object missing")
        if let unifiedObj = addedUnifiedShape, case .shape(let s) = unifiedObj.objectType {
            #expect(s.id == shape.id, "Shape IDs don't match")
        }
    }
}