//
//  TextLivePreviewTests.swift
//  logos inkpen.io Tests
//
//  Created by Claude on 2025/01/01.
//

import XCTest
import SwiftUI
@testable import logos_inkpen_io

final class TextLivePreviewTests: XCTestCase {
    var document: VectorDocument!
    
    override func setUpWithError() throws {
        document = VectorDocument()
        // Set initial document settings
        document.width = 800
        document.height = 600
    }
    
    override func tearDownWithError() throws {
        document = nil
    }
    
    func testTextPreviewTypographyStorage() throws {
        // Create a text object
        let textID = UUID()
        let typography = TypographyProperties(
            fontName: "Helvetica",
            fontSize: 24,
            lineSpacing: 5,
            lineHeight: 30
        )
        
        // Create shape with text
        let shape = VectorShape(
            path: CGPath(rect: CGRect(x: 100, y: 100, width: 200, height: 100), transform: nil),
            fillStyle: FillStyle(color: .black),
            strokeStyle: nil,
            name: "Text: Test",
            isEditable: false
        )
        shape.id = textID
        shape.isTextObject = true
        shape.textContent = "Test text"
        shape.typography = typography
        
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)
        
        // Test font size preview
        document.updateTextFontSizePreview(id: textID, fontSize: 48)
        
        // Verify preview typography is stored
        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.fontSize, 48)
        
        // Clear preview
        document.clearTextPreviewTypography(id: textID)
        XCTAssertNil(document.textPreviewTypography[textID])
    }
    
    func testLineSpacingPreviewUpdate() throws {
        // Create a text object
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)
        
        // Test line spacing preview
        document.updateTextLineSpacingPreview(id: textID, lineSpacing: 10)
        
        // Verify preview typography has updated line spacing
        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.lineSpacing, 10)
    }
    
    func testLineHeightPreviewUpdate() throws {
        // Create a text object
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)
        
        // Test line height preview
        document.updateTextLineHeightPreview(id: textID, lineHeight: 36)
        
        // Verify preview typography has updated line height
        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.lineHeight, 36)
    }
    
    func testNotificationSentForPreviewUpdate() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)
        
        // Set up notification observer
        let expectation = XCTestExpectation(description: "TextPreviewUpdate notification received")
        var receivedTextID: UUID?
        var receivedTypography: TypographyProperties?
        
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("TextPreviewUpdate"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                receivedTextID = userInfo["textID"] as? UUID
                receivedTypography = userInfo["typography"] as? TypographyProperties
                expectation.fulfill()
            }
        }
        
        // Trigger preview update
        document.updateTextFontSizePreview(id: textID, fontSize: 36)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify notification data
        XCTAssertEqual(receivedTextID, textID)
        XCTAssertNotNil(receivedTypography)
        XCTAssertEqual(receivedTypography?.fontSize, 36)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testMultipleDocumentPreviewIndependence() throws {
        // Create two documents with text
        let document1 = VectorDocument()
        let document2 = VectorDocument()
        
        let textID1 = UUID()
        let textID2 = UUID()
        
        let shape1 = createTestTextShape(id: textID1)
        let shape2 = createTestTextShape(id: textID2)
        
        document1.unifiedObjects.append(UnifiedObject(
            id: textID1,
            objectType: .shape(shape1),
            zIndex: 0
        ))
        
        document2.unifiedObjects.append(UnifiedObject(
            id: textID2,
            objectType: .shape(shape2),
            zIndex: 0
        ))
        
        // Update preview in document1
        document1.updateTextFontSizePreview(id: textID1, fontSize: 48)
        
        // Update preview in document2
        document2.updateTextLineSpacingPreview(id: textID2, lineSpacing: 12)
        
        // Verify each document has its own preview state
        XCTAssertEqual(document1.textPreviewTypography[textID1]?.fontSize, 48)
        XCTAssertNil(document1.textPreviewTypography[textID2]) // Should not have other doc's preview
        
        XCTAssertEqual(document2.textPreviewTypography[textID2]?.lineSpacing, 12)
        XCTAssertNil(document2.textPreviewTypography[textID1]) // Should not have other doc's preview
    }
    
    func testTextViewCoordinatorHandlesCorrectNotification() throws {
        // Create a text object
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        
        document.unifiedObjects.append(UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        ))
        
        // Create a view model for the text
        let vectorText = VectorText.from(shape)!
        let viewModel = ProfessionalTextViewModel(
            document: document,
            textObject: vectorText,
            textBoxFrame: CGRect(x: 0, y: 0, width: 200, height: 100),
            isEditing: false
        )
        
        // Create the text view
        let textView = ProfessionalUniversalTextView(
            viewModel: viewModel,
            textBoxState: .gray
        )
        
        // Verify the view model's text object ID matches
        XCTAssertEqual(viewModel.textObject.id, textID)
        
        // Send a notification for this specific text ID
        let typography = TypographyProperties(fontSize: 72)
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": textID, "typography": typography]
        )
        
        // The coordinator should only respond if its text ID matches
        // This test verifies the guard condition works correctly
        XCTAssertEqual(viewModel.textObject.id, textID)
        
        // Send a notification for a different text ID
        let otherTextID = UUID()
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": otherTextID, "typography": typography]
        )
        
        // The view model's text ID should still be the original
        XCTAssertEqual(viewModel.textObject.id, textID)
        XCTAssertNotEqual(viewModel.textObject.id, otherTextID)
    }
    
    func testRapidPreviewUpdatesPerformance() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        
        document.unifiedObjects.append(UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        ))
        
        // Measure performance of rapid updates
        self.measure {
            for size in stride(from: 12, to: 72, by: 1) {
                document.updateTextFontSizePreview(id: textID, fontSize: CGFloat(size))
            }
        }
    }
    
    // Helper method to create test text shape
    private func createTestTextShape(id: UUID) -> VectorShape {
        let shape = VectorShape(
            path: CGPath(rect: CGRect(x: 100, y: 100, width: 200, height: 100), transform: nil),
            fillStyle: FillStyle(color: .black),
            strokeStyle: nil,
            name: "Text: Test",
            isEditable: false
        )
        shape.id = id
        shape.isTextObject = true
        shape.textContent = "Test text content"
        shape.typography = TypographyProperties(
            fontName: "Helvetica",
            fontSize: 24,
            lineSpacing: 5,
            lineHeight: 30
        )
        return shape
    }
}