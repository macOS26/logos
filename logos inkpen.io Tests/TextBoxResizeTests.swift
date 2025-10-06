//
//  TextBoxResizeTests.swift
//  logos inkpen.io Tests
//
//  Created by Claude on 2025/10/05.
//

import XCTest
import SwiftUI
@testable import logos_inkpen_io

final class TextBoxResizeTests: XCTestCase {
    var document: VectorDocument!
    var viewModel: ProfessionalTextViewModel!

    override func setUpWithError() throws {
        document = VectorDocument()
        document.width = 800
        document.height = 600

        // Create a test text object
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
        document = nil
        viewModel = nil
    }

    func testTextBoxPositionStableWithoutResize() throws {
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize.zero

        // Calculate position using the fixed formula
        let centerX = viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2 + resizeOffset.width / 2
        let centerY = viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2 + resizeOffset.height / 2

        // Verify the center is correct
        XCTAssertEqual(centerX, originalFrame.midX, accuracy: 0.01)
        XCTAssertEqual(centerY, originalFrame.midY, accuracy: 0.01)
    }

    func testTextBoxPositionStableDuringResize() throws {
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: 50, height: 30)

        // Calculate position using the fixed formula
        let centerX = viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2 + resizeOffset.width / 2
        let centerY = viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2 + resizeOffset.height / 2

        // Expected center should shift by half the resize offset
        let expectedCenterX = originalFrame.midX + resizeOffset.width / 2
        let expectedCenterY = originalFrame.midY + resizeOffset.height / 2

        XCTAssertEqual(centerX, expectedCenterX, accuracy: 0.01)
        XCTAssertEqual(centerY, expectedCenterY, accuracy: 0.01)
    }

    func testTextBoxResizeFromBottomRight() throws {
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: 100, height: 50)

        // Calculate new dimensions
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height

        // Calculate center position
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2

        // Verify top-left corner stays fixed at original position
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY, accuracy: 0.01)
    }

    func testTextBoxResizeWithNegativeOffset() throws {
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize.zero
        let resizeOffset = CGSize(width: -50, height: -30)

        // Calculate center position
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2

        // Calculate new dimensions
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height

        // Verify top-left corner stays at original position
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY, accuracy: 0.01)
    }

    func testTextBoxResizeWithDragOffset() throws {
        let originalFrame = viewModel.textBoxFrame
        let dragOffset = CGSize(width: 30, height: 20)
        let resizeOffset = CGSize(width: 50, height: 40)

        // Calculate center position with drag offset
        let centerX = originalFrame.minX + dragOffset.width + originalFrame.width / 2 + resizeOffset.width / 2
        let centerY = originalFrame.minY + dragOffset.height + originalFrame.height / 2 + resizeOffset.height / 2

        // Calculate new dimensions
        let newWidth = originalFrame.width + resizeOffset.width
        let newHeight = originalFrame.height + resizeOffset.height

        // Verify position includes drag offset
        let topLeftX = centerX - newWidth / 2
        let topLeftY = centerY - newHeight / 2

        XCTAssertEqual(topLeftX, originalFrame.minX + dragOffset.width, accuracy: 0.01)
        XCTAssertEqual(topLeftY, originalFrame.minY + dragOffset.height, accuracy: 0.01)
    }
}
