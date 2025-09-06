import XCTest
@testable import logos_inkpen_io
import Combine

/// Tests that verify document change notifications are properly sent
/// These tests would catch issues where data is updated but the UI doesn't refresh
class DocumentChangeNotificationTests: XCTestCase {
    var document: VectorDocument!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        document = nil
        super.tearDown()
    }
    
    func testTypographyUpdateSyncsToLegacyArray() {
        // This test would catch the bug where typography wasn't syncing to textObjects array
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                alignment: .left,
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Update typography through unified system
        let newTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontSize: 36,
            alignment: .center,
            strokeColor: .black,
            fillColor: .black
        )
        
        document.updateTextTypographyInUnified(id: textID, typography: newTypography)
        
        // Verify the text was updated in unified system
        if let updatedText = document.allTextObjects.first(where: { $0.id == textID }) {
            XCTAssertEqual(updatedText.typography.fontFamily, "Herculanum", "Font family should be updated in unified system")
            XCTAssertEqual(updatedText.typography.fontSize, 36, "Font size should be updated in unified system")
            XCTAssertEqual(updatedText.typography.fontWeight, FontWeight.bold, "Font weight should be updated in unified system")
            XCTAssertEqual(updatedText.typography.alignment, TextAlignment.center, "Alignment should be updated in unified system")
        } else {
            XCTFail("Text object should exist in unified system after typography update")
        }
    }
    
    func testTypographyUpdateSendsObjectWillChange() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Set up expectation for objectWillChange notification
        let expectation = XCTestExpectation(description: "objectWillChange should be sent")
        
        document.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update typography
        let newTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontSize: 36,
            strokeColor: .black,
            fillColor: .black
        )
        
        document.updateTextTypographyInUnified(id: textID, typography: newTypography)
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFillColorUpdateSendsObjectWillChange() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Set up expectation for objectWillChange notification
        let expectation = XCTestExpectation(description: "objectWillChange should be sent")
        
        document.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update fill color
        document.updateTextFillColorInUnified(id: textID, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)))
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStrokeColorUpdateSendsObjectWillChange() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Set up expectation for objectWillChange notification
        let expectation = XCTestExpectation(description: "objectWillChange should be sent")
        
        document.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Update stroke color
        document.updateTextStrokeColorInUnified(id: textID, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)))
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleUpdatesEachSendNotification() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Count notifications - start counting AFTER setup
        var notificationCount = 0
        
        // Wait a moment for initial setup notifications to complete
        let setupExpectation = XCTestExpectation(description: "Setup complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 0.2)
        
        // Now start counting notifications from updates
        document.objectWillChange
            .sink { _ in
                notificationCount += 1
            }
            .store(in: &cancellables)
        
        // Update typography
        let newTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontSize: 36,
            strokeColor: .black,
            fillColor: .black
        )
        
        let countBefore1 = notificationCount
        document.updateTextTypographyInUnified(id: textID, typography: newTypography)
        let countAfter1 = notificationCount
        XCTAssertGreaterThan(countAfter1, countBefore1, "Typography update should trigger notifications")
        
        // Update fill color
        let countBefore2 = notificationCount
        document.updateTextFillColorInUnified(id: textID, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)))
        let countAfter2 = notificationCount
        XCTAssertGreaterThan(countAfter2, countBefore2, "Fill color update should trigger notifications")
        
        // Update stroke color
        let countBefore3 = notificationCount
        document.updateTextStrokeColorInUnified(id: textID, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)))
        let countAfter3 = notificationCount
        XCTAssertGreaterThan(countAfter3, countBefore3, "Stroke color update should trigger notifications")
    }
}