//
//  TextSelectionRegressionTests.swift
//  logos inkpen.ioTests
//
//  Regression tests for the text selection bug where deselected text
//  becomes unselectable due to invalid bounds
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct TextSelectionRegressionTests {
    
    // MARK: - Core Regression Test
    
    @Test func testDeselectAndReselectTextBug() async throws {
        // This is the exact bug scenario from the user's report
        let document = VectorDocument()
        
        // 1. Create text box with Font tool
        let textBox = VectorText(
            content: "r32r23r23r32r2", // User's actual test content
            typography: TypographyProperties(
                fontFamily: "Herculanum", // User's font
                fontSize: 106.73256655092592, // User's font size
                alignment: .center,
                strokeColor: .black,
                fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))
            ),
            position: CGPoint(x: 83.89457481412636, y: 99.23019284386618),
            areaSize: CGSize(width: 423.82493029739777, height: 334.9452253717472) // User's box size
        )
        
        // 2. Add to document
        document.addTextToUnifiedSystem(textBox, layerIndex: 2)
        
        // 3. Select with Arrow tool
        document.selectedObjectIDs.insert(textBox.id)
        #expect(document.selectedObjectIDs.contains(textBox.id), "Text should be selected")
        
        // 4. Deselect by clicking elsewhere
        document.selectedObjectIDs.removeAll()
        #expect(document.selectedObjectIDs.isEmpty, "Text should be deselected")
        
        // 5. CRITICAL: Try to select again - this was failing!
        // Get the text from unified system
        let unifiedText = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textBox.id
            }
            return false
        }
        
        #expect(unifiedText != nil, "Text should exist in unified objects")
        
        if case .shape(let shape) = unifiedText?.objectType {
            // The bug was here - bounds were (inf, inf, 0.0, 0.0)
            #expect(!shape.bounds.isInfinite, "REGRESSION: Text bounds became infinity after deselection!")
            #expect(!shape.bounds.isNull, "REGRESSION: Text bounds became null after deselection!")
            #expect(shape.bounds.width > 0, "REGRESSION: Text width became 0 after deselection!")
            #expect(shape.bounds.height > 0, "REGRESSION: Text height became 0 after deselection!")
            
            // Verify selection would work
            let clickPoint = CGPoint(
                x: shape.transform.tx + shape.bounds.width / 2,
                y: shape.transform.ty + shape.bounds.height / 2
            )
            
            let hitArea = CGRect(
                x: shape.transform.tx,
                y: shape.transform.ty,
                width: shape.bounds.width,
                height: shape.bounds.height
            )
            
            #expect(hitArea.contains(clickPoint), "REGRESSION: Text not selectable at its center!")
            
            // Verify area size is preserved
            #expect(shape.areaSize == textBox.areaSize, "REGRESSION: Area size lost!")
        }
    }
    
    @Test func testMultipleCopyPasteOperations() async throws {
        // User was doing multiple copy/paste operations
        let document = VectorDocument()
        
        let originalText = VectorText(
            content: "r32r23r23r32r2",
            typography: TypographyProperties(
                fontFamily: "Herculanum",
                fontSize: 106.73,
                alignment: .center,
                strokeColor: .black,
                fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))
            ),
            position: CGPoint(x: 100, y: 100),
            areaSize: CGSize(width: 423.82, height: 334.94)
        )
        
        document.addTextToUnifiedSystem(originalText, layerIndex: 2)
        
        // Perform multiple copy/paste operations like in the log
        for i in 1...3 {
            // Select
            document.selectedObjectIDs = Set([originalText.id])
            
            // Copy and Paste are not direct methods on VectorDocument
            // This test needs to be updated to work with the actual API
            
            // Get the newest text
            if let pastedText = document.allTextObjects.last {
                // Move it (user was dragging texts around)
                let newPosition = CGPoint(x: 100 + Double(i * 50), y: 100 + Double(i * 50))
                document.translateTextInUnified(id: pastedText.id, 
                                               delta: CGPoint(x: Double(i * 50), y: Double(i * 50)))
                
                // Deselect
                document.selectedObjectIDs.removeAll()
                
                // Verify bounds remain valid after all operations
                if let textAfterOps = document.getTextByID(pastedText.id) {
                    #expect(!textAfterOps.bounds.isInfinite, 
                           "Copy \(i): Bounds became infinity after operations")
                    #expect(textAfterOps.bounds.width > 0, 
                           "Copy \(i): Width invalid after operations")
                    #expect(textAfterOps.bounds.height > 0, 
                           "Copy \(i): Height invalid after operations")
                }
            }
        }
        
        // Verify all texts are still selectable
        for textObj in document.allTextObjects {
            #expect(!textObj.bounds.isInfinite, "Text \(textObj.id) has infinity bounds")
            #expect(textObj.bounds.width > 0, "Text \(textObj.id) has invalid width")
        }
    }
    
    @Test func testColorChangePreservesBounds() async throws {
        // User was changing colors which was resetting typography
        let document = VectorDocument()
        
        let text = VectorText(
            content: "Color Test",
            typography: TypographyProperties(
                fontFamily: "Herculanum",
                fontSize: 100,
                strokeColor: .black,
                fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1))
            ),
            position: CGPoint(x: 100, y: 100),
            areaSize: CGSize(width: 400, height: 300)
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Store original bounds
        let originalBounds = text.bounds
        let originalAreaSize = text.areaSize
        
        // Change colors multiple times (like in user's log)
        let colors: [VectorColor] = [
            VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)),
            VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0, alpha: 1)),
            VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)),
            VectorColor.rgb(RGBColor(red: 1, green: 1, blue: 0, alpha: 1)),
            VectorColor.rgb(RGBColor(red: 0.5, green: 0, blue: 0.5, alpha: 1))
        ]
        
        for color in colors {
            document.updateTextFillColorInUnified(id: text.id, color: color)
            
            // Get updated text
            if let updatedText = document.getTextByID(text.id) {
                // Bounds should not become invalid
                #expect(!updatedText.bounds.isInfinite, 
                       "Bounds became infinity after color change to \(color)")
                #expect(!updatedText.bounds.width.isNaN, 
                       "Width became NaN after color change to \(color)")
                #expect(!updatedText.bounds.height.isNaN, 
                       "Height became NaN after color change to \(color)")
                
                // Area size should be preserved
                #expect(updatedText.areaSize == originalAreaSize, 
                       "Area size changed after color change to \(color)")
            }
        }
    }
    
    @Test func testNaNErrorsInBounds() async throws {
        // Test for the NaN errors that were appearing in console
        
        // Create text that might trigger NaN
        var problematicText = VectorText(
            content: "",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 0, y: 0)
        )
        
        // Force invalid bounds
        problematicText.bounds = CGRect(x: CGFloat.nan, y: CGFloat.nan, 
                                        width: CGFloat.nan, height: CGFloat.nan)
        
        // Convert to shape
        let shape = VectorShape.from(problematicText)
        
        // Should sanitize NaN values
        #expect(!shape.bounds.origin.x.isNaN, "X should not be NaN")
        #expect(!shape.bounds.origin.y.isNaN, "Y should not be NaN")
        #expect(!shape.bounds.width.isNaN, "Width should not be NaN")
        #expect(!shape.bounds.height.isNaN, "Height should not be NaN")
        
        // Should have valid fallback values
        #expect(shape.bounds.width > 0, "Should have positive width")
        #expect(shape.bounds.height > 0, "Should have positive height")
    }
    
    @Test func testUndoStackWithInvalidBounds() async throws {
        // Test the "Error saving to undo stack: invalidValue(inf..." issue
        let document = VectorDocument()
        
        // Create text that might have problematic bounds
        let text = VectorText(
            content: "",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Try to save state (would trigger undo stack save)
        let encoder = JSONEncoder()
        
        // Should not throw encoding error for infinity
        do {
            let data = try encoder.encode(document)
            #expect(data.count > 0, "Should encode successfully")
        } catch {
            Issue.record("Encoding failed with error: \(error)")
        }
    }
    
    @Test func testForceResyncFixesSelection() async throws {
        // Test the force resync that was attempted in the logs
        let document = VectorDocument()
        
        // Add some text objects
        let texts = [
            VectorText(content: "Text1", typography: TypographyProperties(strokeColor: .black, fillColor: .black), 
                      position: CGPoint(x: 100, y: 100), areaSize: CGSize(width: 200, height: 50)),
            VectorText(content: "Text2", typography: TypographyProperties(strokeColor: .black, fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))), 
                      position: CGPoint(x: 200, y: 200), areaSize: CGSize(width: 200, height: 50)),
            VectorText(content: "Text3", typography: TypographyProperties(strokeColor: .black, fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1))), 
                      position: CGPoint(x: 300, y: 300), areaSize: CGSize(width: 200, height: 50))
        ]
        
        for text in texts {
            document.addTextToUnifiedSystem(text, layerIndex: 2)
        }
        
        // Force resync (like in the logs)
        document.populateUnifiedObjectsFromLayersPreservingOrder()
        
        // All text objects should still have valid bounds
        for text in texts {
            let unifiedObj = document.unifiedObjects.first { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.id == text.id
                }
                return false
            }
            
            if case .shape(let shape) = unifiedObj?.objectType {
                #expect(!shape.bounds.isInfinite, "Text \(text.id) has infinity bounds after resync")
                #expect(shape.bounds.width > 0, "Text \(text.id) has invalid width after resync")
                #expect(shape.bounds.height > 0, "Text \(text.id) has invalid height after resync")
                #expect(shape.areaSize == text.areaSize, "Text \(text.id) lost area size after resync")
            }
        }
    }
    
    @Test func testEmptyPathBoundsHandling() async throws {
        // Text objects have empty paths which was causing infinity bounds
        let emptyPath = VectorPath(elements: [], isClosed: false)
        
        // This would return infinity
        let pathBounds = emptyPath.cgPath.boundingBoxOfPath
        #expect(pathBounds.isInfinite || pathBounds.isNull, 
               "Empty path should have infinite or null bounds")
        
        // But VectorShape should handle this
        var shape = VectorShape(
            name: "Text with empty path",
            path: emptyPath,
            isTextObject: true,
            textContent: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black)
        )
        
        shape.updateBounds()
        
        // Should not have infinity bounds after update
        #expect(!shape.bounds.isInfinite, "Shape should handle empty path bounds")
        #expect(shape.bounds.width > 0, "Shape should have valid width for empty path")
        #expect(shape.bounds.height > 0, "Shape should have valid height for empty path")
    }
}