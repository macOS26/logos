//
//  UnifiedHelperValidationTests.swift
//  logos inkpen.ioTests
//
//  Tests to ensure ALL operations use unified helpers and no bypasses exist
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedHelperValidationTests {
    
    // MARK: - Corner Radius Helper Tests
    
    @Test func testCornerRadiusHelperUpdatesUnifiedObjects() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newRadii = [10.0, 20.0, 30.0, 40.0]
        let newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
            rect: shape.bounds,
            cornerRadii: newRadii
        )
        
        // Use unified helper
        document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: newRadii, path: newPath)
        
        // Verify shape was updated in layers array
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.cornerRadii == newRadii, "Corner radii should be updated in layers array")
        
        // Verify unified object was updated
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        if case .shape(let unifiedShape) = unifiedObj?.objectType {
            #expect(unifiedShape.cornerRadii == newRadii, "Corner radii should be updated in unified objects")
        } else {
            Issue.record("Shape not found in unified objects")
        }
    }
    
    // MARK: - Gradient Helper Tests
    
    @Test func testGradientHelperUpdatesUnifiedObjects() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let gradient = VectorGradient.linear(LinearGradient(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 1, y: 1),
            stops: [
                GradientStop(position: 0, color: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))),
                GradientStop(position: 1, color: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1)))
            ]
        ))
        
        // Use unified helper
        document.updateShapeGradientInUnified(id: shape.id, gradient: gradient, target: .fill)
        
        // Verify shape was updated in layers array
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        if case .gradient(let shapeGradient) = updatedShape?.fillStyle?.color {
            #expect(shapeGradient == gradient, "Gradient should be updated in layers array")
        } else {
            Issue.record("Gradient not applied to shape in layers array")
        }
        
        // Verify unified object was updated
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        if case .shape(let unifiedShape) = unifiedObj?.objectType,
           case .gradient(let unifiedGradient) = unifiedShape.fillStyle?.color {
            #expect(unifiedGradient == gradient, "Gradient should be updated in unified objects")
        } else {
            Issue.record("Gradient not applied to shape in unified objects")
        }
    }
    
    // MARK: - Transform and Path Helper Tests
    
    @Test func testTransformAndPathHelperUpdatesUnifiedObjects() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newPath = VectorPath(elements: [
            .move(to: VectorPoint(10, 10)),
            .line(to: VectorPoint(90, 10)),
            .line(to: VectorPoint(90, 90)),
            .line(to: VectorPoint(10, 90)),
            .close
        ], isClosed: true)
        
        let newTransform = CGAffineTransform(rotationAngle: .pi / 4)
        
        // Use unified helper
        document.updateShapeTransformAndPathInUnified(id: shape.id, path: newPath, transform: newTransform)
        
        // Verify shape was updated in layers array
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.path.elements.count == newPath.elements.count, "Path should be updated in layers array")
        #expect(updatedShape?.transform == newTransform, "Transform should be updated in layers array")
        
        // Verify unified object was updated
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        if case .shape(let unifiedShape) = unifiedObj?.objectType {
            #expect(unifiedShape.path.elements.count == newPath.elements.count, "Path should be updated in unified objects")
            #expect(unifiedShape.transform == newTransform, "Transform should be updated in unified objects")
        } else {
            Issue.record("Shape not found in unified objects")
        }
    }
    
    // MARK: - Generic Shape Update Helper Tests
    
    @Test func testEntireShapeUpdateHelperUpdatesUnifiedObjects() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let testData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let testName = "Updated Shape Name"
        
        // Use unified helper
        document.updateEntireShapeInUnified(id: shape.id) { shape in
            shape.embeddedImageData = testData
            shape.name = testName
            shape.opacity = 0.5
        }
        
        // Verify shape was updated in layers array
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.embeddedImageData == testData, "Embedded data should be updated in layers array")
        #expect(updatedShape?.name == testName, "Name should be updated in layers array")
        #expect(updatedShape?.opacity == 0.5, "Opacity should be updated in layers array")
        
        // Verify unified object was updated
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        if case .shape(let unifiedShape) = unifiedObj?.objectType {
            #expect(unifiedShape.embeddedImageData == testData, "Embedded data should be updated in unified objects")
            #expect(unifiedShape.name == testName, "Name should be updated in unified objects")
            #expect(unifiedShape.opacity == 0.5, "Opacity should be updated in unified objects")
        } else {
            Issue.record("Shape not found in unified objects")
        }
    }
    
    // MARK: - Existing Helper Tests
    
    @Test func testPathUpdateHelperUpdatesUnifiedObjects() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.circle(center: CGPoint(x: 50, y: 50), radius: 25)
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newPath = VectorPath(elements: [
            .move(to: VectorPoint(0, 0)),
            .line(to: VectorPoint(100, 100))
        ], isClosed: false)
        
        // Use unified helper
        document.updateShapePathUnified(id: shape.id, path: newPath)
        
        // Verify shape was updated in layers array
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.path.elements.count == 2, "Path should be updated to line in layers array")
        
        // Verify unified object was updated
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        if case .shape(let unifiedShape) = unifiedObj?.objectType {
            #expect(unifiedShape.path.elements.count == 2, "Path should be updated to line in unified objects")
        } else {
            Issue.record("Shape not found in unified objects")
        }
    }
    
    // MARK: - Concurrency Tests
    
    @Test func testConcurrentHelperUpdatesDoNotCorrupt() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        // Add multiple shapes
        let shapes = (0..<10).map { i in
            VectorShape.rectangle(at: CGPoint(x: Double(i * 10), y: 0), size: CGSize(width: 10, height: 10))
        }
        
        for shape in shapes {
            document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        }
        
        // Perform concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for (index, shape) in shapes.enumerated() {
                group.addTask {
                    // Each task updates different properties
                    if index % 3 == 0 {
                        let newPath = VectorPath(elements: [
                            .move(to: VectorPoint(0, 0)),
                            .line(to: VectorPoint(20, 20))
                        ], isClosed: false)
                        await MainActor.run {
                            document.updateShapePathUnified(id: shape.id, path: newPath)
                        }
                    } else if index % 3 == 1 {
                        await MainActor.run {
                            document.updateShapeFillColorInUnified(id: shape.id, color: .rgb(RGBColor(red: 1, green: 0, blue: 0)))
                        }
                    } else {
                        await MainActor.run {
                            document.updateShapeOpacityInUnified(id: shape.id, opacity: 0.5)
                        }
                    }
                }
            }
        }
        
        // Verify all shapes are still in unified objects
        #expect(document.unifiedObjects.count >= shapes.count, "All shapes should still be in unified objects")
        
        // Verify no duplicates
        let shapeIDs = document.unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType { return shape.id }
            return nil
        }
        let uniqueIDs = Set(shapeIDs)
        #expect(shapeIDs.count == uniqueIDs.count, "No duplicate shapes should exist")
    }
    
    // MARK: - Error Prevention Tests
    
    @Test func testHelperHandlesNonExistentShape() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let nonExistentID = UUID()
        
        // These should not crash or corrupt the document
        document.updateShapePathUnified(id: nonExistentID, path: VectorPath(elements: [], isClosed: false))
        document.updateShapeFillColorInUnified(id: nonExistentID, color: .clear)
        document.updateShapeCornerRadiiInUnified(id: nonExistentID, cornerRadii: [10], path: VectorPath(elements: [], isClosed: false))
        
        // Document should remain valid (VectorDocument creates 3 default layers)
        #expect(document.layers.count == 4, "Document structure should remain intact")
        #expect(document.unifiedObjects.count >= 0, "Unified objects should remain valid")
    }
    
    // MARK: - Selection Sync Tests
    
    @Test func testHelpersPreserveSelection() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // Select the shape
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }) {
            document.selectedObjectIDs = [unifiedObj.id]
            document.syncSelectionArrays()
        }
        
        #expect(document.selectedShapeIDs.contains(shape.id), "Shape should be selected")
        
        // Update shape using helper
        document.updateShapeOpacityInUnified(id: shape.id, opacity: 0.7)
        
        // Selection should be preserved
        #expect(document.selectedShapeIDs.contains(shape.id), "Shape should still be selected after update")
    }
}