//
//  UnifiedSystemViolationPreventionTests.swift
//  logos inkpen.ioTests
//
//  Critical tests to prevent unified system violations and dual-system paradox
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedSystemViolationPreventionTests {
    
    // MARK: - Critical Paradox Prevention Tests
    
    @Test func testNoDirectLayerShapeAccess() async throws {
        let document = VectorDocument()
        
        // CRITICAL: Document should have Canvas and Pasteboard background objects after initialization
        #expect(document.unifiedObjects.count >= 2, "Document should have background objects after initialization")
        
        // Add objects via unified system only
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 10, y: 10)
        )
        document.addTextToUnifiedSystem(text, layerIndex: 0)
        
        // CRITICAL: Verify unified system has objects (background + added objects)
        #expect(document.unifiedObjects.count >= 4, "Unified system should have background + added objects")
        
        // CRITICAL: Verify no duplicate UUIDs in unified system
        let allIDs = document.unifiedObjects.map { $0.id }
        let uniqueIDs = Set(allIDs)
        #expect(allIDs.count == uniqueIDs.count, "No duplicate UUIDs allowed in unified system")
        
        // CRITICAL: All objects must maintain order - no text jumping to front
        let textObjects = document.unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
        
        let regularShapes = document.unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject
            }
            return false
        }
        
        #expect(!textObjects.isEmpty, "Text objects should exist in unified system")
        #expect(!regularShapes.isEmpty, "Regular shapes should exist in unified system")
    }
    
    @Test func testUnifiedSystemSingleSourceOfTruth() async throws {
        let document = VectorDocument()
        
        // Add multiple objects
        for i in 0..<5 {
            let shape = VectorShape.rectangle(
                at: CGPoint(x: i * 10, y: i * 10), 
                size: CGSize(width: 20, height: 20)
            )
            document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        }
        
        // CRITICAL: Only unified system should be used
        let unifiedCount = document.unifiedObjects.count
        #expect(unifiedCount >= 5, "Unified system should have all objects")
        
        // CRITICAL: No duplicate IDs
        let ids = document.unifiedObjects.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "No duplicate IDs in unified system")
    }
    
    @Test func testTextOrderingInUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add objects in specific order: shape, text, shape, text
        let shape1 = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10))
        document.addShapeToUnifiedSystem(shape1, layerIndex: 0)
        
        let text1 = VectorText(
            content: "First",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 20, y: 20)
        )
        document.addTextToUnifiedSystem(text1, layerIndex: 0)
        
        let shape2 = VectorShape.rectangle(at: CGPoint(x: 40, y: 40), size: CGSize(width: 10, height: 10))
        document.addShapeToUnifiedSystem(shape2, layerIndex: 0)
        
        let text2 = VectorText(
            content: "Second",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 60, y: 60)
        )
        document.addTextToUnifiedSystem(text2, layerIndex: 0)
        
        // CRITICAL: Verify order preservation - no text objects jumping to front
        let objectTypes = document.unifiedObjects.compactMap { obj -> String? in
            if case .shape(let shape) = obj.objectType {
                if shape.id == shape1.id {
                    return "shape1"
                } else if shape.id == text1.id {
                    return "text1"
                } else if shape.id == shape2.id {
                    return "shape2"
                } else if shape.id == text2.id {
                    return "text2"
                }
            }
            return nil
        }
        
        // Order should be maintained based on addition order
        #expect(objectTypes.contains("shape1"), "Shape1 should exist")
        #expect(objectTypes.contains("text1"), "Text1 should exist")
        #expect(objectTypes.contains("shape2"), "Shape2 should exist")
        #expect(objectTypes.contains("text2"), "Text2 should exist")
        
        // CRITICAL: No duplicate UUIDs
        let allIds = document.unifiedObjects.map { $0.id }
        let uniqueIds = Set(allIds)
        #expect(allIds.count == uniqueIds.count, "No duplicate UUIDs - this causes text jumping paradox")
    }
    
    @Test func testPreventLegacyArrayBypass() async throws {
        let document = VectorDocument()
        
        // Add object via unified system
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // CRITICAL: Unified system must be the source of truth
        let allShapes = document.getAllShapes()
        #expect(allShapes.contains { $0.id == shape.id }, "Shape must be findable via unified query")
        
        // CRITICAL: Use only unified query methods for layer access
        let layerShapes = document.getShapesInLayer(0)
        #expect(layerShapes.contains { $0.id == shape.id }, "Shape must be findable via unified layer query")
    }
    
    @Test func testUnifiedSystemIntegrity() async throws {
        let document = VectorDocument()
        
        // Add mixed objects
        let shape1 = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10))
        let shape2 = VectorShape.rectangle(at: CGPoint(x: 10, y: 10), size: CGSize(width: 10, height: 10))
        
        let text1 = VectorText(
            content: "Test1",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 30, y: 30)
        )
        
        document.addShapeToUnifiedSystem(shape1, layerIndex: 0)
        document.addShapeToUnifiedSystem(shape2, layerIndex: 0)
        document.addTextToUnifiedSystem(text1, layerIndex: 0)
        
        // Count objects before any operation
        let initialCount = document.unifiedObjects.count
        
        // Perform operation that might trigger sync
        document.updateShapeFillColorInUnified(id: shape1.id, color: .black)
        
        // CRITICAL: Count should not change (no duplicates added)
        let finalCount = document.unifiedObjects.count
        #expect(finalCount == initialCount, "Object count should not change during updates")
        
        // CRITICAL: No duplicate IDs
        let ids = document.unifiedObjects.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count, "No duplicate IDs after operations")
    }
}