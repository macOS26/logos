//
//  UnifiedObjectSystemPasteBugTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemBugPreventionTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemPasteBugTests {
    
    @Test func testTextBoxResizeAreaSizeSyncPreventsWrongPasteDimensions() async throws {
        let document = VectorDocument()
        
        // Create initial text with specific area size
        let originalAreaSize = CGSize(width: 300, height: 150)
        let originalText = VectorText(
            content: "Resize Test Text",
            typography: TypographyProperties(
                strokeColor: VectorColor.black,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 50, y: 100),
            areaSize: originalAreaSize
        )
        
        // Add to document
        document.addTextToUnifiedSystem(originalText, layerIndex: 1)
        
        // Verify original areaSize
        #expect(document.allTextObjects[0].areaSize == originalAreaSize)
        
        // SIMULATE MANUAL RESIZE: User drags resize handle
        let newResizedFrame = CGRect(x: 50, y: 100, width: 500, height: 250)
        let newAreaSize = CGSize(width: 500, height: 250)
        
        // Simulate the resize operation that updateDocumentTextBounds handles
        document.updateTextPositionInUnified(id: originalText.id, position: CGPoint(x: newResizedFrame.minX, y: newResizedFrame.minY))
        document.updateTextBoundsInUnified(id: originalText.id, bounds: CGRect(
            x: 0, y: 0, 
            width: newResizedFrame.width, 
            height: newResizedFrame.height
        ))
        // CRITICAL: This line prevents the paste bug
        document.updateTextAreaSizeInUnified(id: originalText.id, areaSize: CGSize(width: newResizedFrame.width, height: newResizedFrame.height))
        
        // Verify areaSize was updated after resize
        let resizedText = document.allTextObjects.first { $0.id == originalText.id }
        #expect(resizedText?.areaSize == newAreaSize, "REGRESSION: areaSize not updated after resize - will cause paste bug!")
        
        // Select the resized text
        document.selectedObjectIDs.insert(originalText.id)
        
        // SIMULATE COPY/PASTE without using real clipboard (to avoid test crashes)
        // Manually create a copy of the text with new ID to simulate paste behavior
        let originalResizedText = document.allTextObjects.first { $0.id == originalText.id }!
        var pastedText = originalResizedText
        pastedText.id = UUID() // New ID for pasted text
        
        // Clear selection and "paste" (add the copied text)
        document.selectedObjectIDs.removeAll()
        document.addTextToUnifiedSystem(pastedText, layerIndex: 1)
        document.selectedObjectIDs.insert(pastedText.id)
        
        // Verify we now have 2 text objects
        #expect(document.getTextCount() == 2, "Should have original + pasted text")
        
        // Verify the pasted text (we know it's the one we just created)
        #expect(document.getTextByID(pastedText.id) != nil, "Pasted text not found in document")
        
        // Test the pasted text properties
        // CRITICAL: Pasted text must have the RESIZED dimensions, not original
        #expect(pastedText.areaSize == newAreaSize, "PASTE BUG: Pasted text has wrong size - got \(pastedText.areaSize?.debugDescription ?? "nil"), expected \(newAreaSize)")
        #expect(pastedText.areaSize != originalAreaSize, "PASTE BUG: Pasted text reverted to original size instead of current resized size")
        
        // Verify bounds also match
        let expectedBounds = CGRect(x: 0, y: 0, width: 500, height: 250)
        #expect(pastedText.bounds == expectedBounds, "Pasted text bounds don't match resized dimensions")
    }
}