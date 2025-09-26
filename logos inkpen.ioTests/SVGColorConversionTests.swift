//
//  SVGColorConversionTests.swift
//  logos inkpen.io Tests
//
//  Testing sRGB to Display P3 color conversion in SVG import

import XCTest
@testable import logos_inkpen_io

final class SVGColorConversionTests: XCTestCase {

    let parser = SVGStyleParser()

    func testSRGBBlueConvertsToP3Blue() {
        // sRGB blue (0, 121/255, 255/255) should convert to P3 blue (0, 0.478, 1)
        let svgBlue = parser.parseColor("rgb(0, 121, 255)")

        // Extract the RGB color from VectorColor
        guard case .rgb(let rgbColor) = svgBlue else {
            XCTFail("Expected RGB color")
            return
        }

        // P3 blue should have green value around 0.478
        XCTAssertEqual(rgbColor.red, 0.0, accuracy: 0.001, "Red component should be 0")
        XCTAssertEqual(rgbColor.green, 0.478, accuracy: 0.01, "Green should be ~0.478 in P3")
        XCTAssertEqual(rgbColor.blue, 1.0, accuracy: 0.001, "Blue component should be 1")
        XCTAssertEqual(rgbColor.colorSpace, .displayP3, "Should be in Display P3 color space")
    }

    func testHexBlueConvertsToP3Blue() {
        // Hex #0079FF (sRGB blue) should also convert to P3 blue
        let hexBlue = parser.parseColor("#0079FF")

        guard case .rgb(let rgbColor) = hexBlue else {
            XCTFail("Expected RGB color")
            return
        }

        XCTAssertEqual(rgbColor.red, 0.0, accuracy: 0.001, "Red component should be 0")
        XCTAssertEqual(rgbColor.green, 0.478, accuracy: 0.01, "Green should be ~0.478 in P3")
        XCTAssertEqual(rgbColor.blue, 1.0, accuracy: 0.001, "Blue component should be 1")
        XCTAssertEqual(rgbColor.colorSpace, .displayP3, "Should be in Display P3 color space")
    }

    func testNamedBlueConvertsToP3Blue() {
        // Named "blue" should also convert properly
        let namedBlue = parser.parseColor("blue")

        guard case .rgb(let rgbColor) = namedBlue else {
            XCTFail("Expected RGB color")
            return
        }

        // sRGB blue (0,0,1) converts to a slightly different P3 blue
        XCTAssertEqual(rgbColor.red, 0.0, accuracy: 0.001, "Red component should be 0")
        // Pure sRGB blue (0,0,1) maps to a slightly different P3 value than (0,121/255,1)
        XCTAssertEqual(rgbColor.blue, 1.0, accuracy: 0.001, "Blue component should be 1")
        XCTAssertEqual(rgbColor.colorSpace, .displayP3, "Should be in Display P3 color space")
    }

    func testSRGBRedConvertsToP3Red() {
        // sRGB red should convert to P3 red
        let svgRed = parser.parseColor("rgb(255, 0, 0)")

        guard case .rgb(let rgbColor) = svgRed else {
            XCTFail("Expected RGB color")
            return
        }

        // P3 red is slightly different from sRGB red
        XCTAssertEqual(rgbColor.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgbColor.green, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgbColor.blue, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgbColor.colorSpace, .displayP3)
    }

    func testConsistentColorConversion() {
        // Test that the same color from different sources converts to the same P3 value
        let rgb121Blue = parser.parseColor("rgb(0, 121, 255)")
        let hex79Blue = parser.parseColor("#0079FF") // 79 hex = 121 decimal

        guard case .rgb(let rgb1) = rgb121Blue,
              case .rgb(let rgb2) = hex79Blue else {
            XCTFail("Expected RGB colors")
            return
        }

        // Both should produce identical P3 colors
        XCTAssertEqual(rgb1.red, rgb2.red, accuracy: 0.001)
        XCTAssertEqual(rgb1.green, rgb2.green, accuracy: 0.001)
        XCTAssertEqual(rgb1.blue, rgb2.blue, accuracy: 0.001)
    }
}