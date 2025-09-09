import XCTest
import CoreGraphics
import PDFKit
@testable import logos_inkpen_io

class TestGradientAngle: XCTestCase {
    
    func testNormalizedGradientAnglePreserved() throws {
        // Create a document with a 90° gradient using normalized coordinates
        let document = VectorDocument()
        document.settings.sizeInPoints = CGSize(width: 1024, height: 1024)
        
        // Create a gradient with 90° angle
        var linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0.5, y: 0),
            endPoint: CGPoint(x: 0.5, y: 1),
            stops: [
                GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
                GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
            ]
        )
        
        // Verify initial angle is 90°
        let initialAngle = linearGradient.angle
        print("Initial gradient angle: \(initialAngle)°")
        XCTAssertEqual(initialAngle, 90.0, accuracy: 0.1, "Initial gradient should be 90°")
        
        // Create a shape with the gradient
        let path = VectorPath(elements: [
            .move(to: VectorPoint(x: 100, y: 100)),
            .line(to: VectorPoint(x: 924, y: 100)),
            .line(to: VectorPoint(x: 924, y: 924)),
            .line(to: VectorPoint(x: 100, y: 924)),
            .close
        ])
        
        let shape = VectorShape(
            path: path,
            fillStyle: FillStyle(gradient: .linear(linearGradient)),
            strokeStyle: nil
        )
        
        document.unifiedObjects.append(shape)
        
        // Export to PDF
        let pdfData = try FileOperations.generatePDFData(from: document)
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        
        // Save and reload
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_normalized_gradient.pdf")
        try pdfData.write(to: tempURL)
        
        // Import the PDF back
        let importedDocument = try FileOperations.importPDF(from: tempURL)
        
        // Verify gradient angle is preserved
        if let importedShape = importedDocument.unifiedObjects.first as? VectorShape,
           let fillStyle = importedShape.fillStyle,
           case .gradient(let importedGradient) = fillStyle.color,
           case .linear(let importedLinear) = importedGradient {
            
            print("Imported gradient angle: \(importedLinear.angle)°")
            print("Imported gradient storedAngle: \(importedLinear.storedAngle)°")
            
            // The angle should be 90°, not -90°
            XCTAssertEqual(importedLinear.angle, 90.0, accuracy: 1.0, 
                          "Imported gradient angle should be 90° not -90° (was \(importedLinear.angle)°)")
        } else {
            XCTFail("Could not extract gradient from imported shape")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
}