import XCTest
@testable import logos_inkpen_io
import Foundation

class SVGImportTest: XCTestCase {
    
    func testSVGImportAddsShapesToUnifiedObjects() throws {
        // Create a simple SVG with one rectangle
        let svgContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <rect x="10" y="10" width="80" height="80" fill="red"/>
        </svg>
        """
        
        let svgData = svgContent.data(using: .utf8)!
        
        // Import the SVG
        let document = try FileOperations.importFromSVGData(svgData)
        
        // Check unified objects count
        print("🔍 Unified objects count after import: \(document.unifiedObjects.count)")
        
        // Should have at least 3 objects: Canvas Background, Pasteboard Background, and the imported rectangle
        XCTAssertGreaterThanOrEqual(document.unifiedObjects.count, 3)
        
        // Check if the imported shape is in layer 2 (working layer)
        let workingLayerShapes = document.unifiedObjects.filter { $0.layerIndex == 2 }
        print("🔍 Working layer shapes count: \(workingLayerShapes.count)")
        XCTAssertGreaterThanOrEqual(workingLayerShapes.count, 1)
        
        // Verify the shape is visible
        if let firstShape = workingLayerShapes.first,
           case .shape(let shape) = firstShape.objectType {
            print("🔍 Shape name: \(shape.name), visible: \(shape.isVisible)")
            XCTAssertTrue(shape.isVisible)
        }
    }
    
    func testSVGImportViaFileOpen() throws {
        // Create a simple SVG with shapes
        let svgContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
            <path d="M100,100 L200,100 L200,200 L100,200 Z" fill="blue"/>
            <path d="M300,300 L400,300 L400,400 L300,400 Z" fill="green"/>
        </svg>
        """
        
        let svgData = svgContent.data(using: .utf8)!
        
        // Import the SVG using the method that File > Open uses
        let document = try FileOperations.importFromSVGData(svgData)
        
        // Simulate what InkpenDocument does after import
        document.populateUnifiedObjectsFromLayersPreservingOrder()
        document.updateUnifiedObjectsOptimized()
        
        // Check unified objects
        print("🔍 Unified objects after populate: \(document.unifiedObjects.count)")
        
        // Count non-background shapes
        let nonBackgroundShapes = document.unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.name.contains("Background")
            }
            return false
        }
        
        print("🔍 Non-background shapes: \(nonBackgroundShapes.count)")
        XCTAssertGreaterThanOrEqual(nonBackgroundShapes.count, 2) // Should have our 2 paths
        
        // Check they're on the correct layer
        for obj in nonBackgroundShapes {
            print("🔍 Shape layer: \(obj.layerIndex)")
            XCTAssertEqual(obj.layerIndex, 2) // Working layer
        }
    }
}