//
//  UnifiedClippingMaskTests.swift
//  logos inkpen.ioTests
//
//  Tests for clipping mask functionality with unified object system
//  Ensures no duplicates and proper refresh behavior
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedClippingMaskTests {
    
    // MARK: - Clipping Mask Creation Tests
    
    @Test func testClippingMaskCreationNoDuplicates() async throws {
        let document = VectorDocument()
        
        // Create two shapes
        let rect = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        let circle = VectorShape.circle(center: CGPoint(x: 75, y: 75), radius: 25)
        
        // Add shapes to document
        document.addShapeToUnifiedSystem(rect, layerIndex: 2)
        document.addShapeToUnifiedSystem(circle, layerIndex: 2)
        
        // Verify initial state - no duplicates
        let initialShapeCount = document.getShapeCount(layerIndex: 2)
        let initialUnifiedCount = document.unifiedObjects.count
        #expect(initialShapeCount == 2, "Should have exactly 2 shapes in layer")
        
        // Select both shapes
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == rect.id || shape.id == circle.id {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        
        // Create clipping mask
        document.makeClippingMaskFromSelection()
        
        // Verify no duplicates were created
        let afterShapeCount = document.getShapeCount(layerIndex: 2)
        let afterUnifiedCount = document.unifiedObjects.count
        
        #expect(afterShapeCount == 2, "Should still have exactly 2 shapes after clipping mask creation")
        #expect(afterUnifiedCount == initialUnifiedCount, "Unified object count should not change")
        
        // Verify clipping relationships are correct
        let maskShape = document.getShapesForLayer(2).first { $0.id == circle.id }
        let clippedShape = document.getShapesForLayer(2).first { $0.id == rect.id }
        
        #expect(maskShape?.isClippingPath == true, "Circle should be marked as clipping path")
        #expect(clippedShape?.clippedByShapeID == circle.id, "Rectangle should be clipped by circle")
        
        // Verify no duplicate IDs in unified objects
        let unifiedIDs = document.unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType {
                return shape.id
            }
            return nil
        }
        let uniqueIDs = Set(unifiedIDs)
        #expect(unifiedIDs.count == uniqueIDs.count, "No duplicate shape IDs should exist in unified objects")
    }
    
    @Test func testClippingMaskWithMultipleShapes() async throws {
        let document = VectorDocument()
        
        // Create three shapes
        let rect1 = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        let rect2 = VectorShape.rectangle(at: CGPoint(x: 20, y: 20), size: CGSize(width: 80, height: 80))
        let maskShape = VectorShape.circle(center: CGPoint(x: 60, y: 60), radius: 35)
        
        // Add shapes to document
        document.addShapeToUnifiedSystem(rect1, layerIndex: 2)
        document.addShapeToUnifiedSystem(rect2, layerIndex: 2)
        document.addShapeToUnifiedSystem(maskShape, layerIndex: 2)
        
        // Select all shapes
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == rect1.id || shape.id == rect2.id || shape.id == maskShape.id {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        
        // Create clipping mask (top shape becomes mask)
        document.makeClippingMaskFromSelection()
        
        // Verify clipping relationships
        let mask = document.getShapesForLayer(2).first { $0.id == maskShape.id }
        let clipped1 = document.getShapesForLayer(2).first { $0.id == rect1.id }
        let clipped2 = document.getShapesForLayer(2).first { $0.id == rect2.id }
        
        #expect(mask?.isClippingPath == true, "Ellipse should be clipping path")
        #expect(clipped1?.clippedByShapeID == maskShape.id, "First rectangle should be clipped")
        #expect(clipped2?.clippedByShapeID == maskShape.id, "Second rectangle should be clipped")
        
        // Verify unified objects are in sync
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType {
                if shape.id == maskShape.id {
                    #expect(shape.isClippingPath == true, "Mask should be marked in unified objects")
                } else if shape.id == rect1.id || shape.id == rect2.id {
                    #expect(shape.clippedByShapeID == maskShape.id, "Clipped shapes should have correct ID in unified objects")
                }
            }
        }
    }
    
    // MARK: - Clipping Mask Release Tests
    
    @Test func testClippingMaskRelease() async throws {
        let document = VectorDocument()
        
        // Create and setup clipping mask
        let rect = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        let circle = VectorShape.circle(center: CGPoint(x: 75, y: 75), radius: 25)
        
        document.addShapeToUnifiedSystem(rect, layerIndex: 2)
        document.addShapeToUnifiedSystem(circle, layerIndex: 2)
        
        // Select and create clipping mask
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == rect.id || shape.id == circle.id {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        document.makeClippingMaskFromSelection()
        
        // Verify mask was created
        let maskBefore = document.getShapesForLayer(2).first { $0.id == circle.id }
        #expect(maskBefore?.isClippingPath == true, "Mask should be created")
        
        // Release clipping mask
        document.releaseClippingMaskForSelection()
        
        // Verify mask was released
        let maskAfter = document.getShapesForLayer(2).first { $0.id == circle.id }
        let clippedAfter = document.getShapesForLayer(2).first { $0.id == rect.id }
        
        #expect(maskAfter?.isClippingPath == false, "Mask flag should be cleared")
        #expect(clippedAfter?.clippedByShapeID == nil, "Clipping relationship should be cleared")
        
        // Verify unified objects are updated
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType {
                if shape.id == circle.id {
                    #expect(shape.isClippingPath == false, "Mask flag should be cleared in unified objects")
                } else if shape.id == rect.id {
                    #expect(shape.clippedByShapeID == nil, "Clipping ID should be cleared in unified objects")
                }
            }
        }
    }
    
    // MARK: - Clipping Mask Movement Tests
    
    @Test func testClippingMaskMovement() async throws {
        let document = VectorDocument()
        
        // Create shapes
        let rect = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        let circle = VectorShape.circle(center: CGPoint(x: 75, y: 75), radius: 25)
        
        document.addShapeToUnifiedSystem(rect, layerIndex: 2)
        document.addShapeToUnifiedSystem(circle, layerIndex: 2)
        
        // Create clipping mask
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == rect.id || shape.id == circle.id {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        document.makeClippingMaskFromSelection()
        
        // Get initial positions
        let maskBefore = document.getShapesForLayer(2).first { $0.id == circle.id }!
        let clippedBefore = document.getShapesForLayer(2).first { $0.id == rect.id }!
        let maskInitialBounds = maskBefore.bounds
        let clippedInitialBounds = clippedBefore.bounds
        
        // Move clipping mask
        let offset = CGPoint(x: 100, y: 100)
        document.moveClippingMask(circle.id, by: offset)
        
        // Verify both shapes moved
        let maskAfter = document.getShapesForLayer(2).first { $0.id == circle.id }!
        let clippedAfter = document.getShapesForLayer(2).first { $0.id == rect.id }!
        
        let expectedMaskBounds = CGRect(
            x: maskInitialBounds.minX + offset.x,
            y: maskInitialBounds.minY + offset.y,
            width: maskInitialBounds.width,
            height: maskInitialBounds.height
        )
        
        let expectedClippedBounds = CGRect(
            x: clippedInitialBounds.minX + offset.x,
            y: clippedInitialBounds.minY + offset.y,
            width: clippedInitialBounds.width,
            height: clippedInitialBounds.height
        )
        
        #expect(abs(maskAfter.bounds.minX - expectedMaskBounds.minX) < 0.01, "Mask X position should be updated")
        #expect(abs(maskAfter.bounds.minY - expectedMaskBounds.minY) < 0.01, "Mask Y position should be updated")
        #expect(abs(clippedAfter.bounds.minX - expectedClippedBounds.minX) < 0.01, "Clipped shape X position should be updated")
        #expect(abs(clippedAfter.bounds.minY - expectedClippedBounds.minY) < 0.01, "Clipped shape Y position should be updated")
    }
    
    // MARK: - Unified System Sync Tests
    
    @Test func testUnifiedSystemSyncAfterClippingMask() async throws {
        let document = VectorDocument()
        
        // Add multiple shapes
        let shapes = (0..<5).map { i in
            VectorShape.rectangle(
                at: CGPoint(x: Double(i * 20), y: Double(i * 20)),
                size: CGSize(width: 50, height: 50)
            )
        }
        
        for shape in shapes {
            document.addShapeToUnifiedSystem(shape, layerIndex: 2)
        }
        
        let initialUnifiedCount = document.unifiedObjects.count
        
        // Create clipping mask with last two shapes
        let lastTwo = shapes.suffix(2)
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if lastTwo.contains(where: { $0.id == shape.id }) {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        document.makeClippingMaskFromSelection()
        
        // Verify unified count didn't change
        #expect(document.unifiedObjects.count == initialUnifiedCount, "Unified object count should remain the same")
        
        // Verify all shapes are still in unified objects
        for shape in shapes {
            let exists = document.unifiedObjects.contains { obj in
                if case .shape(let s) = obj.objectType {
                    return s.id == shape.id
                }
                return false
            }
            #expect(exists, "Shape \(shape.id) should still exist in unified objects")
        }
        
        // Verify clipping relationships in unified objects
        let maskId = shapes.last!.id
        let clippedId = shapes[shapes.count - 2].id
        
        for unifiedObj in document.unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType {
                if shape.id == maskId {
                    #expect(shape.isClippingPath == true, "Mask should be marked in unified objects")
                } else if shape.id == clippedId {
                    #expect(shape.clippedByShapeID == maskId, "Clipped shape should have correct relationship in unified objects")
                }
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test func testClippingMaskWithSingleShapeDoesNothing() async throws {
        let document = VectorDocument()
        
        let rect = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(rect, layerIndex: 2)
        
        // Select single shape
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == rect.id
            }
            return false
        }) {
            document.selectedObjectIDs = [unifiedObj.id]
            document.syncSelectionArrays()
        }
        
        // Try to create clipping mask
        document.makeClippingMaskFromSelection()
        
        // Verify nothing changed
        let shape = document.getShapesForLayer(2).first { $0.id == rect.id }
        #expect(shape?.isClippingPath == false, "Single shape should not become clipping path")
        #expect(shape?.clippedByShapeID == nil, "Single shape should not be clipped")
    }
    
    @Test func testRepeatedClippingMaskCreationNoDuplicates() async throws {
        let document = VectorDocument()
        
        let rect = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        let circle = VectorShape.circle(center: CGPoint(x: 75, y: 75), radius: 25)
        
        document.addShapeToUnifiedSystem(rect, layerIndex: 2)
        document.addShapeToUnifiedSystem(circle, layerIndex: 2)
        
        // Select both shapes
        document.selectedObjectIDs = Set(document.unifiedObjects.compactMap { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == rect.id || shape.id == circle.id {
                    return obj.id
                }
            }
            return nil
        })
        document.syncSelectionArrays()
        
        // Create clipping mask multiple times
        for _ in 0..<3 {
            document.makeClippingMaskFromSelection()
        }
        
        // Verify no duplicates
        #expect(document.getShapesForLayer(2).count == 2, "Should still have exactly 2 shapes")
        #expect(document.unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == rect.id || shape.id == circle.id
            }
            return false
        }.count <= 4, "Should not have duplicate unified objects") // 2 shapes + 2 system layers = 4 max
        
        // Verify clipping still works
        let maskShape = document.getShapesForLayer(2).first { $0.id == circle.id }
        #expect(maskShape?.isClippingPath == true, "Mask should still be set")
    }
}
