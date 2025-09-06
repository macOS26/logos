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
    
    func testTypographyUpdateSendsObjectWillChange() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .regular,
                fontStyle: .normal,
                underlineStyle: .none,
                strikethroughStyle: .none,
                alignment: .left,
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
            fontSize: 36,
            fontWeight: .bold,
            fontStyle: .normal,
            underlineStyle: .none,
            strikethroughStyle: .none,
            alignment: .left,
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
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .regular,
                fontStyle: .normal,
                underlineStyle: .none,
                strikethroughStyle: .none,
                alignment: .left,
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
        document.updateTextFillColorInUnified(id: textID, color: .red)
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStrokeColorUpdateSendsObjectWillChange() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .regular,
                fontStyle: .normal,
                underlineStyle: .none,
                strikethroughStyle: .none,
                alignment: .left,
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
        document.updateTextStrokeColorInUnified(id: textID, color: .blue)
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMultipleUpdatesEachSendNotification() {
        // Create text
        let textObj = VectorText(
            content: "Test",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .regular,
                fontStyle: .normal,
                underlineStyle: .none,
                strikethroughStyle: .none,
                alignment: .left,
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addText(textObj)
        let textID = textObj.id
        
        // Count notifications
        var notificationCount = 0
        
        document.objectWillChange
            .sink { _ in
                notificationCount += 1
            }
            .store(in: &cancellables)
        
        // Update typography
        let newTypography = TypographyProperties(
            fontFamily: "Herculanum",
            fontSize: 36,
            fontWeight: .bold,
            fontStyle: .normal,
            underlineStyle: .none,
            strikethroughStyle: .none,
            alignment: .left,
            strokeColor: .black,
            fillColor: .black
        )
        
        document.updateTextTypographyInUnified(id: textID, typography: newTypography)
        XCTAssertEqual(notificationCount, 1, "First update should send notification")
        
        // Update fill color
        document.updateTextFillColorInUnified(id: textID, color: .red)
        XCTAssertEqual(notificationCount, 2, "Second update should send notification")
        
        // Update stroke color
        document.updateTextStrokeColorInUnified(id: textID, color: .blue)
        XCTAssertEqual(notificationCount, 3, "Third update should send notification")
    }
}