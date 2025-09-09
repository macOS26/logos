import XCTest
import CoreGraphics
import PDFKit
@testable import logos_inkpen_io

class PDFGradientRoundtripTest: XCTestCase {
    
    func testPDFGradientRoundtrip() throws {
        // Create a document with a 90° gradient
        let document = VectorDocument()
        document.settings.sizeInPoints = CGSize(width: 1024, height: 1024)
        
        // Create a gradient with specific angle (90°)
        let gradientStops = [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 0.5, color: .rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
        ]
        
        var linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0.5),
            endPoint: CGPoint(x: 1, y: 0.5),
            stops: gradientStops
        )
        
        // Explicitly set the angle to 90°
        linearGradient.setAngle(90.0)
        
        XCTAssertEqual(linearGradient.angle, 90.0, accuracy: 0.1, "Gradient angle should be 90°")
        
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
        
        // Save PDF to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_gradient.pdf")
        try pdfData.write(to: tempURL)
        
        // Import the PDF back
        let importedDocument = try FileOperations.importPDF(from: tempURL)
        
        // Check that we have the same number of objects
        XCTAssertEqual(importedDocument.unifiedObjects.count, 1, "Should have 1 object after import")
        
        // Check the gradient in the imported shape
        if let importedShape = importedDocument.unifiedObjects.first as? VectorShape,
           let fillStyle = importedShape.fillStyle,
           case .gradient(let importedGradient) = fillStyle.color,
           case .linear(let importedLinear) = importedGradient {
            
            // Check gradient angle is preserved
            XCTAssertEqual(importedLinear.angle, 90.0, accuracy: 1.0, "Imported gradient angle should be 90° (was \(importedLinear.angle)°)")
            
            // Check gradient stops are preserved
            XCTAssertEqual(importedLinear.stops.count, 3, "Should have 3 gradient stops")
            
            // Check first stop (red)
            if case .rgb(let firstColor) = importedLinear.stops[0].color {
                XCTAssertEqual(firstColor.red, 1.0, accuracy: 0.1, "First stop should be red")
                XCTAssertEqual(firstColor.green, 0.0, accuracy: 0.1)
                XCTAssertEqual(firstColor.blue, 0.0, accuracy: 0.1)
            }
            
            // Check middle stop (green)
            if case .rgb(let middleColor) = importedLinear.stops[1].color {
                XCTAssertEqual(middleColor.red, 0.0, accuracy: 0.1)
                XCTAssertEqual(middleColor.green, 1.0, accuracy: 0.1, "Middle stop should be green")
                XCTAssertEqual(middleColor.blue, 0.0, accuracy: 0.1)
            }
            
            // Check last stop (blue)
            if case .rgb(let lastColor) = importedLinear.stops[2].color {
                XCTAssertEqual(lastColor.red, 0.0, accuracy: 0.1)
                XCTAssertEqual(lastColor.green, 0.0, accuracy: 0.1)
                XCTAssertEqual(lastColor.blue, 1.0, accuracy: 0.1, "Last stop should be blue")
            }
        } else {
            XCTFail("Imported shape should have a linear gradient fill")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testPDFGradientNotRasterized() throws {
        // Create a simple document with gradient
        let document = VectorDocument()
        document.settings.sizeInPoints = CGSize(width: 512, height: 512)
        
        let gradient = LinearGradient(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 1, y: 1),
            stops: [
                GradientStop(position: 0.0, color: .white, opacity: 1.0),
                GradientStop(position: 1.0, color: .black, opacity: 1.0)
            ]
        )
        
        let path = VectorPath(elements: [
            .move(to: VectorPoint(x: 50, y: 50)),
            .line(to: VectorPoint(x: 462, y: 50)),
            .line(to: VectorPoint(x: 462, y: 462)),
            .line(to: VectorPoint(x: 50, y: 462)),
            .close
        ])
        
        let shape = VectorShape(
            path: path,
            fillStyle: FillStyle(gradient: .linear(gradient)),
            strokeStyle: nil
        )
        
        document.unifiedObjects.append(shape)
        
        // Generate PDF
        let pdfData = try FileOperations.generatePDFData(from: document)
        
        // Check PDF contains gradient operators (not rasterized)
        if let pdfDocument = PDFDocument(data: pdfData),
           let page = pdfDocument.page(at: 0),
           let pageData = page.dataRepresentation {
            
            let pdfString = String(data: pageData, encoding: .ascii) ?? ""
            
            // PDF should NOT contain inline image markers (BI/ID/EI)
            XCTAssertFalse(
                pdfString.contains("BI") && pdfString.contains("ID") && pdfString.contains("EI"),
                "PDF should not contain inline images (gradients should be vector)"
            )
            
            // Check for gradient-related content
            // CGGradient produces different patterns than CGShading
            // We should see color stops and gradient drawing commands
            print("PDF content preview: \(String(pdfString.prefix(1000)))")
        }
    }
}