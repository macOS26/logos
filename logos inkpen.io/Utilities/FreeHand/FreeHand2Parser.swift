import Foundation
import CoreGraphics

enum FreeHand2Parser {
    // MARK: - Constants

    private static let headerSize = 256
    private static let magic: [UInt8] = [0x46, 0x48, 0x44, 0x32] // "FHD2"
    private static let pathRecordType: UInt16 = 0x151C
    private static let ovalRecordType: UInt16 = 0x151A
    private static let terminator: UInt32 = 0xFFFFFFFF
    private static let unitsPerPoint: Double = 10.0 // 720 DPI / 72 DPI

    // Point type codes
    private static let cornerPointType: UInt16 = 0x001B
    private static let curvePointType: UInt16 = 0x0009

    // MARK: - FH2 Point

    private struct FH2Point {
        let type: UInt16
        /// Incoming control handle (or on-curve position for corner points)
        let controlIn: CGPoint
        /// On-curve position
        let onCurve: CGPoint
        /// Outgoing control handle (or on-curve position for corner points)
        let controlOut: CGPoint

        var isCorner: Bool { type == cornerPointType }
    }

    // MARK: - Helpers

    private static func readUInt16BE(_ data: Data, offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) << 8 | UInt16(data[base + 1])
    }

    private static func readInt16BE(_ data: Data, offset: Int) -> Int16 {
        return Int16(bitPattern: readUInt16BE(data, offset: offset))
    }

    private static func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base]) << 24
             | UInt32(data[base + 1]) << 16
             | UInt32(data[base + 2]) << 8
             | UInt32(data[base + 3])
    }

    // MARK: - Public API

    static func parseToShapes(data: Data) throws -> FreeHandDirectImporter.Result {
        // Validate minimum size and magic
        guard data.count >= headerSize + 4 else {
            throw FreeHandImportError.notSupported
        }
        for i in 0..<4 {
            guard data[data.startIndex + i] == magic[i] else {
                throw FreeHandImportError.notSupported
            }
        }

        // Extract page dimensions (720 DPI units -> points)
        let pageWidthRaw = Double(readUInt16BE(data, offset: 8))
        let pageHeightRaw = Double(readUInt16BE(data, offset: 10))
        let pageWidth = pageWidthRaw / unitsPerPoint
        let pageHeight = pageHeightRaw / unitsPerPoint
        let pageSize = CGSize(width: pageWidth, height: pageHeight)

        // Scan for 0x151C path records by searching for the type marker.
        // The encoding tables before graphic records have a different structure,
        // so we scan for the type code and validate the size field 2 bytes before.
        var shapes: [VectorShape] = []
        var offset = headerSize

        while offset + 4 <= data.count {
            let word = readUInt16BE(data, offset: offset)

            // Look for a path record type at offset+2 (size at offset)
            if offset + 44 <= data.count {
                let rtype = readUInt16BE(data, offset: offset + 2)

                if rtype == pathRecordType && word >= 44 && offset + Int(word) <= data.count {
                    let recordSize = Int(word)
                    let pointCount = Int(readUInt16BE(data, offset: offset + 28))
                    let expectedSize = 44 + pointCount * 16
                    if recordSize == expectedSize {
                        if let shape = parsePathRecord(data: data, recordOffset: offset,
                                                       recordSize: recordSize,
                                                       pageHeight: pageHeight) {
                            shapes.append(shape)
                        }
                    }
                } else if rtype == ovalRecordType && word == 56 && offset + 40 <= data.count {
                    if let shape = parseOvalRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight) {
                        shapes.append(shape)
                    }
                }
            }

            // Not a recognized record — advance by 1 byte (records can be at odd offsets)
            offset += 1
        }

        guard !shapes.isEmpty else {
            throw FreeHandImportError.emptyOutput
        }

        let stats = FreeHandDirectImporter.Stats(
            paths: shapes.count,
            groups: 0,
            clipGroups: 0,
            compositePaths: 0,
            newBlends: 0,
            symbolInstances: 0,
            contentIdPaths: 0
        )

        return FreeHandDirectImporter.Result(
            shapes: shapes,
            pageSize: pageSize,
            stats: stats
        )
    }

    // MARK: - Record Parsing

    private static func parsePathRecord(data: Data, recordOffset: Int,
                                        recordSize: Int,
                                        pageHeight: Double) -> VectorShape? {
        // Minimum path record: 44 bytes header + 0 points
        guard recordSize >= 44 else { return nil }

        let pointCount = Int(readUInt16BE(data, offset: recordOffset + 28))
        guard pointCount > 0 else { return nil }

        // Validate record size matches expected: 44 + pointCount * 16
        let expectedSize = 44 + pointCount * 16
        guard recordSize >= expectedSize else { return nil }

        // Parse points — data starts at +30 (the 0000 pad after point count
        // serves as the first point's leading separator)
        let pointDataStart = recordOffset + 30
        var fh2Points: [FH2Point] = []
        fh2Points.reserveCapacity(pointCount)

        // Offset within point block: each point is 16 bytes
        // Layout: 2 bytes separator, 2 bytes type, then 6x Int16 coords
        for i in 0..<pointCount {
            let pOffset = pointDataStart + i * 16

            // Skip 2-byte separator (always 0x0000)
            let pointType = readUInt16BE(data, offset: pOffset + 2)

            // Read 3 coordinate pairs as Int16 BE
            let x1 = Double(readInt16BE(data, offset: pOffset + 4))
            let y1 = Double(readInt16BE(data, offset: pOffset + 6))
            let x2 = Double(readInt16BE(data, offset: pOffset + 8))
            let y2 = Double(readInt16BE(data, offset: pOffset + 10))
            let x3 = Double(readInt16BE(data, offset: pOffset + 12))
            let y3 = Double(readInt16BE(data, offset: pOffset + 14))

            // Convert from FH2 units (720/inch) to points (72/inch)
            // Flip Y: y_screen = pageHeight - y_fh2_points
            let controlIn = CGPoint(
                x: x1 / unitsPerPoint,
                y: pageHeight - y1 / unitsPerPoint
            )
            let onCurve = CGPoint(
                x: x2 / unitsPerPoint,
                y: pageHeight - y2 / unitsPerPoint
            )
            let controlOut = CGPoint(
                x: x3 / unitsPerPoint,
                y: pageHeight - y3 / unitsPerPoint
            )

            fh2Points.append(FH2Point(
                type: pointType,
                controlIn: controlIn,
                onCurve: onCurve,
                controlOut: controlOut
            ))
        }

        // Convert FH2 points to path elements
        let elements = buildPathElements(from: fh2Points)
        guard !elements.isEmpty else { return nil }

        // Determine if path is closed: first on-curve == last on-curve
        let firstOnCurve = fh2Points[0].onCurve
        let lastOnCurve = fh2Points[fh2Points.count - 1].onCurve
        let isClosed = fh2Points.count > 1
            && abs(firstOnCurve.x - lastOnCurve.x) < 0.01
            && abs(firstOnCurve.y - lastOnCurve.y) < 0.01

        let path = VectorPath(
            elements: elements,
            isClosed: isClosed,
            fillRule: .winding
        )

        // Decode attributes from record header
        // +12: fill gray byte (0=white, 0x7F=black — Mac convention, inverted from PostScript)
        // +14: stroke gray byte (same scale)
        let fillGrayByte = data[recordOffset + 12]
        let strokeGrayByte = data[recordOffset + 14]

        // Convert from Mac gray (0=white, 127=black) to RGB (0=black, 1=white)
        let fillGray = 1.0 - Double(fillGrayByte) / 127.0
        let strokeGray = 1.0 - Double(strokeGrayByte) / 127.0

        // +26: closed/filled flag (1 = closed path with fill)
        let filledFlag = readUInt16BE(data, offset: recordOffset + 26)

        // Build stroke style — use thin stroke, color from gray byte
        let strokeColor = VectorColor.rgb(RGBColor(
            red: strokeGray, green: strokeGray, blue: strokeGray
        ))
        let strokeStyle = StrokeStyle(color: strokeColor, width: 0.5)

        // Build fill style — only for closed filled paths
        var fillStyle: FillStyle? = nil
        if filledFlag == 1 && isClosed {
            let fillColor = VectorColor.rgb(RGBColor(
                red: fillGray, green: fillGray, blue: fillGray
            ))
            fillStyle = FillStyle(color: fillColor)
        }

        // Detect geometric shape type
        var detectedType: GeometricShapeType?
        var baseName = "Path"
        if let detected = PathShapeDetector.detect(elements: elements) {
            detectedType = detected.type
            baseName = detected.name
        }

        return VectorShape(
            name: baseName,
            path: path,
            geometricType: detectedType,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    // MARK: - Oval Record Parsing

    private static func parseOvalRecord(data: Data, recordOffset: Int,
                                         pageHeight: Double) -> VectorShape? {
        // Bounding box at +26 to +33 (4 × Int16 BE): left, top, right, bottom
        let left = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let top = Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let right = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let bottom = Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint

        let width = right - left
        let height = top - bottom  // FH2 Y-up: top > bottom
        guard width > 0.1 && height > 0.1 else { return nil }

        // Convert to screen coords (Y flip)
        let cx = left + width / 2.0
        let cy = pageHeight - (bottom + height / 2.0)
        let rx = width / 2.0
        let ry = height / 2.0

        // Approximate ellipse with 4 cubic Bézier segments
        let k: Double = 0.5522847498  // kappa for circular arc
        let elements: [PathElement] = [
            .move(to: VectorPoint(cx + rx, cy)),
            .curve(to: VectorPoint(cx, cy - ry),
                   control1: VectorPoint(cx + rx, cy - ry * k),
                   control2: VectorPoint(cx + rx * k, cy - ry)),
            .curve(to: VectorPoint(cx - rx, cy),
                   control1: VectorPoint(cx - rx * k, cy - ry),
                   control2: VectorPoint(cx - rx, cy - ry * k)),
            .curve(to: VectorPoint(cx, cy + ry),
                   control1: VectorPoint(cx - rx, cy + ry * k),
                   control2: VectorPoint(cx - rx * k, cy + ry)),
            .curve(to: VectorPoint(cx + rx, cy),
                   control1: VectorPoint(cx + rx * k, cy + ry),
                   control2: VectorPoint(cx + rx, cy + ry * k)),
            .close
        ]

        let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)

        // Decode colors same as path records
        let fillGrayByte = data[recordOffset + 12]
        let strokeGrayByte = data[recordOffset + 14]
        let fillGray = 1.0 - Double(fillGrayByte) / 127.0
        let strokeGray = 1.0 - Double(strokeGrayByte) / 127.0

        let strokeColor = VectorColor.rgb(RGBColor(red: strokeGray, green: strokeGray, blue: strokeGray))
        let strokeStyle = StrokeStyle(color: strokeColor, width: 0.5)

        let fillColor = VectorColor.rgb(RGBColor(red: fillGray, green: fillGray, blue: fillGray))
        let fillStyle = FillStyle(color: fillColor)

        return VectorShape(
            name: "Ellipse",
            path: path,
            geometricType: .ellipse,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    // MARK: - Path Element Construction

    private static func buildPathElements(from points: [FH2Point]) -> [PathElement] {
        guard let first = points.first else { return [] }

        var elements: [PathElement] = []
        elements.reserveCapacity(points.count + 1) // +1 for potential close

        // First point is always a moveTo
        elements.append(.move(to: VectorPoint(first.onCurve.x, first.onCurve.y)))

        // Determine if path is closed (first == last on-curve)
        let lastOnCurve = points[points.count - 1].onCurve
        let isClosed = points.count > 1
            && abs(first.onCurve.x - lastOnCurve.x) < 0.01
            && abs(first.onCurve.y - lastOnCurve.y) < 0.01

        // How many segments to emit: if closed, the last point is a duplicate
        // of the first so we stop before it
        let segmentCount = isClosed ? points.count - 1 : points.count - 1

        for i in 0..<segmentCount {
            let prev = points[i]
            let next = points[(i + 1) % points.count]

            // Check if both the outgoing control of prev and the incoming
            // control of next are coincident with their on-curve points
            let prevOutCoincident =
                abs(prev.controlOut.x - prev.onCurve.x) < 0.01
                && abs(prev.controlOut.y - prev.onCurve.y) < 0.01
            let nextInCoincident =
                abs(next.controlIn.x - next.onCurve.x) < 0.01
                && abs(next.controlIn.y - next.onCurve.y) < 0.01

            if prevOutCoincident && nextInCoincident {
                // Straight line segment
                elements.append(.line(to: VectorPoint(next.onCurve.x, next.onCurve.y)))
            } else {
                // Cubic Bezier curve
                elements.append(.curve(
                    to: VectorPoint(next.onCurve.x, next.onCurve.y),
                    control1: VectorPoint(prev.controlOut.x, prev.controlOut.y),
                    control2: VectorPoint(next.controlIn.x, next.controlIn.y)
                ))
            }
        }

        if isClosed {
            elements.append(.close)
        }

        return elements
    }
}
