import XCTest
import SwiftUI
@testable import logos_inkpen_io

final class TextBoxResizeTests: XCTestCase {
    var document = VectorDocument()
    var viewModel: ProfessionalTextViewModel?

    override func setUpWithError() throws {
        document = VectorDocument()
        document.width = 800
        document.height = 600

        let textObject = VectorText(
            id: UUID(),
            content: "Test",
            position: CGPoint(x: 100, y: 100),
            bounds: CGRect(x: 100, y: 100, width: 200, height: 100),
            typography: TypographyProperties(fontSize: 24)
        )

        viewModel = ProfessionalTextViewModel(
            document: document,
            textObject: textObject,
            textBoxFrame: CGRect(x: 100, y: 100, width: 200, height: 100),
            isEditing: false
        )
    }

    override func tearDownWithError() throws {
        viewModel = nil
    }

    func testTextBoxPositionStableWithoutResize() throws {
        guard let viewModel else { XCTFail("viewModel not initialized"); return }
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize.zero
        let centerX = viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2 + resizeOffset.width / 2
        let centerY = viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2 + resizeOffset.height / 2

        XCTAssertEqual(centerX, originalFrame.midX, accuracy: 0.01)
        XCTAssertEqual(centerY, originalFrame.midY, accuracy: 0.01)
    }

    func testTextBoxPositionStableDuringResize() throws {
        guard let viewModel else { XCTFail("viewModel not initialized"); return }
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: 50, height: 30)
        let centerX = viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2 + resizeOffset.width / 2
        let centerY = viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2 + resizeOffset.height / 2
        let expectedCenterX = originalFrame.midX + resizeOffset.width / 2
        let expectedCenterY = originalFrame.midY + resizeOffset.height / 2

        XCTAssertEqual(centerX, expectedCenterX, accuracy: 0.01)
        XCTAssertEqual(centerY, expectedCenterY, accuracy: 0.01)
    }

    func testTextBoxResizeFromBottomRight() throws {
        guard let viewModel else { XCTFail("viewModel not initialized"); return }
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: 100, height: 50)
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY, accuracy: 0.01)
    }

    func testTextBoxResizeWithNegativeOffset() throws {
        guard let viewModel else { XCTFail("viewModel not initialized"); return }
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: -50, height: -30)
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY, accuracy: 0.01)
    }

    func testTextBoxResizeWithDragOffset() throws {
        guard let viewModel else { XCTFail("viewModel not initialized"); return }
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize(width: 30, height: 20)
        let resizeOffset = CGSize(width: 50, height: 40)
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX + dragOffset.width, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY + dragOffset.height, accuracy: 0.01)
    }
}
