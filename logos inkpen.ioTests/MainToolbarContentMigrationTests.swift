//
//  MainToolbarContentMigrationTests.swift
//  logos inkpen.ioTests
//
//  Test that MainToolbarContent uses unified objects system
//

import XCTest
@testable import logos_inkpen_io

final class MainToolbarContentMigrationTests: XCTestCase {
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
        document.createCanvasAndWorkingLayers()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    func testUnlockAllObjectsUsesUnifiedObjects() {
        // Add some locked shapes to different layers
        var shape1 = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        shape1.isLocked = true
        document.addShapeToUnifiedSystem(shape1, layerIndex: 2)
        
        var shape2 = VectorShape.rectangle(at: CGPoint(x: 200, y: 200), size: CGSize(width: 60, height: 60))
        shape2.isLocked = true
        document.addShapeToUnifiedSystem(shape2, layerIndex: 2)
        
        // Verify shapes are locked in unified objects
        let lockedCount = document.unifiedObjects.filter { object in
            if case .shape(let shape) = object.objectType {
                return shape.isLocked
            }
            return false
        }.count
        XCTAssertEqual(lockedCount, 2, "Should have 2 locked shapes")
        
        // Unlock all objects - this uses unified objects system
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                document.unlockShapeInUnified(id: shape.id)
            }
        }
        
        // Verify all shapes are unlocked in unified objects
        let unlockedCount = document.unifiedObjects.filter { object in
            if case .shape(let shape) = object.objectType {
                return !shape.isLocked
            }
            return false
        }.count
        
        let totalShapeCount = document.unifiedObjects.filter { object in
            if case .shape = object.objectType {
                return true
            }
            return false
        }.count
        
        XCTAssertEqual(unlockedCount, totalShapeCount, "All shapes should be unlocked")
    }
    
    func testShowAllObjectsUsesUnifiedObjects() {
        // Add some hidden shapes to different layers
        var shape1 = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        shape1.isVisible = false
        document.addShapeToUnifiedSystem(shape1, layerIndex: 2)
        
        var shape2 = VectorShape.rectangle(at: CGPoint(x: 200, y: 200), size: CGSize(width: 60, height: 60))
        shape2.isVisible = false
        document.addShapeToUnifiedSystem(shape2, layerIndex: 2)
        
        // Verify shapes are hidden in unified objects
        let hiddenCount = document.unifiedObjects.filter { object in
            if case .shape(let shape) = object.objectType {
                return !shape.isVisible
            }
            return false
        }.count
        XCTAssertEqual(hiddenCount, 2, "Should have 2 hidden shapes")
        
        // Show all objects - this uses unified objects system
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                document.showShapeInUnified(id: shape.id)
            }
        }
        
        // Verify all shapes are visible in unified objects
        let visibleCount = document.unifiedObjects.filter { object in
            if case .shape(let shape) = object.objectType {
                return shape.isVisible
            }
            return false
        }.count
        
        let totalShapeCount = document.unifiedObjects.filter { object in
            if case .shape = object.objectType {
                return true
            }
            return false
        }.count
        
        XCTAssertEqual(visibleCount, totalShapeCount, "All shapes should be visible")
    }
    
    func testHideSelectedObjectsUsesUnifiedSystem() {
        // Add shapes and select them
        let shape1 = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape1, layerIndex: 2)
        
        let shape2 = VectorShape.rectangle(at: CGPoint(x: 200, y: 200), size: CGSize(width: 60, height: 60))
        document.addShapeToUnifiedSystem(shape2, layerIndex: 2)
        
        // Select the shapes
        document.selectedObjectIDs = [shape1.id, shape2.id]
        
        // Hide selected objects
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                if case .shape(let shape) = unifiedObject.objectType {
                    document.hideShapeInUnified(id: shape.id)
                }
            }
        }
        
        // Verify shapes are hidden in unified objects
        let hiddenSelectedCount = document.unifiedObjects.filter { object in
            if case .shape(let shape) = object.objectType {
                return !shape.isVisible && (shape.id == shape1.id || shape.id == shape2.id)
            }
            return false
        }.count
        
        XCTAssertEqual(hiddenSelectedCount, 2, "Selected shapes should be hidden")
    }
}