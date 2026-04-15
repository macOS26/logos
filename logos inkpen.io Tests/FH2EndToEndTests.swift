import XCTest
@testable import logos_inkpen_io

/// End-to-end diagnostic for FH2 → VectorDocument → SVG.
/// Loads torfont.fh2 from ~/Downloads, parses it, dumps the color/style chain,
/// writes the resulting SVG to /tmp so a human can eyeball the output.
final class FH2EndToEndTests: XCTestCase {

    func testTorfontFH2ColorAndLayerPipeline() throws {
        let url = URL(fileURLWithPath: NSString(string: "~/Downloads/torfont.fh2").expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("torfont.fh2 not found at \(url.path)")
        }
        let data = try Data(contentsOf: url)

        // 1. Color table diagnostics
        let (colorTable, widthTable) = FreeHand2Parser.debugColorTable(data: data)
        print("=== COLOR TABLE (\(colorTable.count) entries) ===")
        for id in colorTable.keys.sorted() {
            print("  id=\(id): \(colorTable[id]!)")
        }
        print("=== WIDTH TABLE (\(widthTable.count) entries) ===")
        for id in widthTable.keys.sorted() {
            print("  id=\(id): \(widthTable[id]!)")
        }

        // 2. Parse via full pipeline
        let result = try FreeHand2Parser.parseToShapes(data: data)
        print("=== PARSE RESULT ===")
        print("  shapes: \(result.shapes.count)")
        print("  layers: \(result.layers.count) \(result.layers.map { $0.name })")
        print("  groups: \(result.groups.count) \(result.groups.map { $0.name })")
        print("  page:   \(result.pageSize)")

        // 3. Each shape's resolved fill/stroke
        print("=== SHAPES ===")
        for (i, shape) in result.shapes.enumerated() {
            let fill = shape.fillStyle.map { "\($0.color)" } ?? "nil"
            let strokeColor = "\(shape.strokeStyle.color)"
            print("  [\(i)] name=\(shape.name) fill=\(fill) stroke=\(strokeColor) w=\(shape.strokeStyle.width)")
        }

        // 4. Build a VectorDocument the same way InkpenDocument does,
        //    then export SVG to /tmp so the human can eyeball it.
        let newDoc = VectorDocument()
        newDoc.settings.setSizeInPoints(result.pageSize)
        newDoc.onSettingsChanged()
        let layerIndex = newDoc.selectedLayerIndex
            ?? newDoc.snapshot.layers.firstIndex(where: { $0.name == "Layer 1" })
            ?? (newDoc.snapshot.layers.count - 1)
        for shape in result.shapes {
            newDoc.addImportedShape(shape, to: layerIndex)
        }

        let svg = try SVGExporter.shared.exportToSVG(newDoc, includeBackground: false, textRenderingMode: .lines, includeInkpenData: false)
        let outURL = URL(fileURLWithPath: "/tmp/torfont_fh2_roundtrip.svg")
        try svg.write(to: outURL, atomically: true, encoding: .utf8)
        print("=== SVG written: \(outURL.path) (\(svg.count) bytes) ===")

        // Sanity assertions
        XCTAssertGreaterThan(result.shapes.count, 0, "should parse at least one shape")
        XCTAssertGreaterThan(colorTable.count, 0, "should build non-empty color table")
    }
}
