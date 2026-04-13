import Foundation
import CoreGraphics

enum FreeHand2Parser {
    // MARK: - Constants

    private static let headerSize = 256
    private static let magic: [UInt8] = [0x46, 0x48, 0x44, 0x32] // "FHD2"
    private static let pathRecordType: UInt16 = 0x151C
    private static let ovalRecordType: UInt16 = 0x151A
    private static let rectRecordType: UInt16 = 0x1519
    private static let lineRecordType: UInt16 = 0x151D
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

    // MARK: - Color Table

    /// Record entry in the sequential ID table
    private struct RecordEntry {
        let offset: Int
        let type: UInt16
        let size: Int
    }

    /// Build sequential ID → record offset table and extract colors
    enum GradientType { case linear, radial }

    struct GradientInfo {
        let type: GradientType
        let colors: [VectorColor]  // Supports 2+ stops
    }

    private static func buildColorAndWidthTables(data: Data) -> ([Int: VectorColor], [Int: Double], [Int: GradientInfo]) {
        var colorTable: [Int: VectorColor] = [:]
        var widthTable: [Int: Double] = [:]
        var gradientTable: [Int: GradientInfo] = [:]

        // Read starting child ID from first TABLE (0x0005) record
        var firstChildID = 18
        for i in stride(from: headerSize, to: min(data.count - 10, headerSize + 2000), by: 1) {
            guard i + 6 <= data.count else { break }
            if readUInt16BE(data, offset: i + 2) == 0x0005 {
                let size = Int(readUInt16BE(data, offset: i))
                if size >= 16 && size < 200 {
                    let count = Int(readUInt16BE(data, offset: i + 4))
                    if count > 0 && i + 10 < data.count {
                        firstChildID = Int(readUInt16BE(data, offset: i + 10))
                    }
                    break
                }
            }
        }

        // Scan ALL non-shape records in one pass, assign sequential IDs
        // Colors (0x1452-0x1454) and styles (0x14B0-0x14FF) share the same ID space
        var allRecords: [(offset: Int, type: UInt16)] = []
        let shapeTypes: Set<UInt16> = [rectRecordType, ovalRecordType, pathRecordType, lineRecordType]
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            // Match color records
            if (rtype == 0x1452 && size == 30) ||
               (rtype == 0x1453 && size == 30) ||
               (rtype == 0x1454 && size == 32 && offset + 22 <= data.count) {
                allRecords.append((offset, rtype))
            }
            // Match ALL style/attribute records (0x14B0+ and 0x157D)
            else if (rtype >= 0x14B0 && rtype <= 0x14FF && size >= 10 && size <= 100) ||
                    (rtype == 0x157D && size >= 10 && size <= 100) {
                allRecords.append((offset, rtype))
            }
            offset += 1
        }

        // Assign sequential IDs and extract data
        for (idx, rec) in allRecords.enumerated() {
            let rid = firstChildID + idx
            let off = rec.offset

            // Color extraction
            if rec.type == 0x1452 || rec.type == 0x1453 {
                let r = Double(readUInt16BE(data, offset: off + 6)) / 65535.0
                let g = Double(readUInt16BE(data, offset: off + 8)) / 65535.0
                let b = Double(readUInt16BE(data, offset: off + 10)) / 65535.0
                let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                colorTable[rid] = color
                // Also store by eid for out-of-range ref lookups
                let eid = Int(readUInt16BE(data, offset: off + 4))
                if eid > 0 { colorTable[eid] = color }
            } else if rec.type == 0x1454 {
                let c = Double(readUInt16BE(data, offset: off + 14)) / 65535.0
                let m = Double(readUInt16BE(data, offset: off + 16)) / 65535.0
                let y = Double(readUInt16BE(data, offset: off + 18)) / 65535.0
                let k = Double(readUInt16BE(data, offset: off + 20)) / 65535.0
                let r = (1 - c) * (1 - k); let g = (1 - m) * (1 - k); let b = (1 - y) * (1 - k)
                let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                colorTable[rid] = color
                let eid = Int(readUInt16BE(data, offset: off + 4))
                if eid > 0 { colorTable[eid] = color }
            }

            // Style: follow inner_ref to color
            if rec.type >= 0x14B0 && off + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: off + 10))

                // SC (0x14B7): gradient with TWO color refs at +10 and +12
                if rec.type == 0x14B7 && off + 14 <= data.count {
                    let ref2 = Int(readUInt16BE(data, offset: off + 12))
                    if let c1 = colorTable[innerRef], let c2 = colorTable[ref2] {
                        gradientTable[rid] = GradientInfo(type: .linear, colors: [c2, c1])
                        colorTable[rid] = c1 // flat fallback = first color
                    }
                } else if innerRef > 0, let color = colorTable[innerRef] {
                    colorTable[rid] = color
                } else if innerRef == 0 {
                    if let black = colorTable[firstChildID] {
                        colorTable[rid] = black
                    }
                }
            }

            // SB (0x14B6): stroke width at +18
            if rec.type == 0x14B6 && off + 20 <= data.count {
                let rawWidth = Int(readUInt16BE(data, offset: off + 18))
                if rawWidth > 0 {
                    widthTable[rid] = Double(rawWidth) / 10.0
                }
            }
        }

        return (colorTable, widthTable, gradientTable)
    }

    // MARK: - Debug

    static func debugColorTable(data: Data) -> ([Int: VectorColor], [Int: Double]) {
        let (ct, wt, _) = buildColorAndWidthTables(data: data)
        return (ct, wt)
    }

    static func debugGradientTable(data: Data) -> [Int: GradientInfo] {
        let (_, _, gt) = buildColorAndWidthTables(data: data)
        return gt
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

        // Build color, width, and gradient lookup tables from sequential record IDs
        let (colorTable, widthTable, gradientTable) = buildColorAndWidthTables(data: data)

        // Scan for shape records
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
                                                       pageHeight: pageHeight,
                                                       colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                            shapes.append(shape)
                        }
                    }
                } else if rtype == ovalRecordType && word == 56 && offset + 40 <= data.count {
                    if let shape = parseOvalRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                    }
                } else if rtype == rectRecordType && word == 60 && offset + 44 <= data.count {
                    if let shape = parseRectRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                    }
                } else if rtype == lineRecordType && word == 48 && offset + 40 <= data.count {
                    if let shape = parseLineRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
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
                                        pageHeight: Double,
                                        colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
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

        // Extract fill and stroke colors from color table
        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: isClosed)

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

    // MARK: - Color Extraction from Record Attributes

    private static func extractFillStroke(data: Data, recordOffset: Int,
                                           colorTable: [Int: VectorColor],
                                           widthTable: [Int: Double],
                                           gradientTable: [Int: GradientInfo] = [:],
                                           isClosed: Bool) -> (fill: FillStyle?, stroke: StrokeStyle?) {
        let fillRef = Int(readUInt16BE(data, offset: recordOffset + 18))
        let strokeRef = Int(readUInt16BE(data, offset: recordOffset + 20))

        // Check +13 byte: 0x80 flag means "white/paper fill" (CMYK 0,0,0,0)
        let whiteFillFlag = data[recordOffset + 13] & 0x80 != 0

        // Look up fill color from color table
        var fillStyle: FillStyle? = nil
        if isClosed && whiteFillFlag {
            fillStyle = FillStyle(color: .white)
        } else if isClosed && fillRef > 0 {
            // Check for gradient fill first
            if let grad = gradientTable[fillRef], grad.colors.count >= 2 {
                var stops: [GradientStop] = []
                for (i, color) in grad.colors.enumerated() {
                    let pos = grad.colors.count > 1 ? Double(i) / Double(grad.colors.count - 1) : 0
                    stops.append(GradientStop(position: pos, color: color))
                }
                switch grad.type {
                case .linear:
                    let linear = LinearGradient(
                        startPoint: CGPoint(x: 0, y: 0.5),
                        endPoint: CGPoint(x: 1, y: 0.5),
                        stops: stops
                    )
                    fillStyle = FillStyle(color: .gradient(.linear(linear)))
                case .radial:
                    let radial = RadialGradient(
                        centerPoint: CGPoint(x: 0.5, y: 0.5),
                        radius: 0.5,
                        stops: stops
                    )
                    fillStyle = FillStyle(color: .gradient(.radial(radial)))
                }
            } else if let fillColor = colorTable[fillRef] {
                fillStyle = FillStyle(color: fillColor)
            } else {
                // Fallback: use grayscale from +12 byte
                let fillGrayByte = data[recordOffset + 12]
                let fillGray = 1.0 - Double(fillGrayByte) / 127.0
                fillStyle = FillStyle(color: .rgb(RGBColor(red: fillGray, green: fillGray, blue: fillGray)))
            }
        }

        // Look up stroke color and width from tables
        let strokeWidth = widthTable[strokeRef] ?? 0.5
        let strokeStyle: StrokeStyle
        if let strokeColor = colorTable[strokeRef] {
            strokeStyle = StrokeStyle(color: strokeColor, width: strokeWidth)
        } else {
            let strokeGrayByte = data[recordOffset + 14]
            let strokeGray = 1.0 - Double(strokeGrayByte) / 127.0
            strokeStyle = StrokeStyle(color: .rgb(RGBColor(red: strokeGray, green: strokeGray, blue: strokeGray)), width: strokeWidth)
        }

        return (fillStyle, strokeStyle)
    }

    // MARK: - Rectangle Record Parsing (0x1519)

    private static func parseRectRecord(data: Data, recordOffset: Int,
                                         pageHeight: Double,
                                         colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        // Bounding box at +26 to +33 (4 × Int16 BE): left, top, right, bottom
        let left = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let top = Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let right = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let bottom = Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint

        let width = right - left
        let height = top - bottom  // FH2 Y-up
        guard width > 0.1 && height > 0.1 else { return nil }

        // Corner radius at +38 and +40 (Int16 BE, FH2 units)
        let cornerRadiusX = Double(readUInt16BE(data, offset: recordOffset + 38)) / unitsPerPoint
        let cornerRadiusY = Double(readUInt16BE(data, offset: recordOffset + 40)) / unitsPerPoint
        let cr = min(cornerRadiusX, cornerRadiusY, width / 2, height / 2)

        // Convert to screen coords (Y flip)
        let x = left
        let y = pageHeight - top

        let elements: [PathElement]
        if cr > 0.1 {
            // Rounded rectangle
            let k: Double = 0.5522847498
            elements = [
                .move(to: VectorPoint(x + cr, y)),
                .line(to: VectorPoint(x + width - cr, y)),
                .curve(to: VectorPoint(x + width, y + cr),
                       control1: VectorPoint(x + width - cr + cr * k, y),
                       control2: VectorPoint(x + width, y + cr - cr * k)),
                .line(to: VectorPoint(x + width, y + height - cr)),
                .curve(to: VectorPoint(x + width - cr, y + height),
                       control1: VectorPoint(x + width, y + height - cr + cr * k),
                       control2: VectorPoint(x + width - cr + cr * k, y + height)),
                .line(to: VectorPoint(x + cr, y + height)),
                .curve(to: VectorPoint(x, y + height - cr),
                       control1: VectorPoint(x + cr - cr * k, y + height),
                       control2: VectorPoint(x, y + height - cr + cr * k)),
                .line(to: VectorPoint(x, y + cr)),
                .curve(to: VectorPoint(x + cr, y),
                       control1: VectorPoint(x, y + cr - cr * k),
                       control2: VectorPoint(x + cr - cr * k, y)),
                .close
            ]
        } else {
            elements = [
                .move(to: VectorPoint(x, y)),
                .line(to: VectorPoint(x + width, y)),
                .line(to: VectorPoint(x + width, y + height)),
                .line(to: VectorPoint(x, y + height)),
                .close
            ]
        }

        let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: true)

        return VectorShape(
            name: cr > 0.1 ? "Rounded Rectangle" : "Rectangle",
            path: path,
            geometricType: .rectangle,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            opacity: 1.0
        )
    }

    // MARK: - Line Record Parsing (0x151D)

    private static func parseLineRecord(data: Data, recordOffset: Int,
                                          pageHeight: Double,
                                          colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
        // Line endpoints at +26 to +33 (4 × Int16 BE): x1, y1, x2, y2
        let x1 = Double(readInt16BE(data, offset: recordOffset + 26)) / unitsPerPoint
        let y1 = pageHeight - Double(readInt16BE(data, offset: recordOffset + 28)) / unitsPerPoint
        let x2 = Double(readInt16BE(data, offset: recordOffset + 30)) / unitsPerPoint
        let y2 = pageHeight - Double(readInt16BE(data, offset: recordOffset + 32)) / unitsPerPoint

        let elements: [PathElement] = [
            .move(to: VectorPoint(x1, y1)),
            .line(to: VectorPoint(x2, y2))
        ]

        let path = VectorPath(elements: elements, isClosed: false, fillRule: .winding)
        let (_, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                  colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: false)

        return VectorShape(
            name: "Line",
            path: path,
            geometricType: nil,
            strokeStyle: strokeStyle,
            fillStyle: nil,
            opacity: 1.0
        )
    }

    // MARK: - Oval Record Parsing

    private static func parseOvalRecord(data: Data, recordOffset: Int,
                                         pageHeight: Double,
                                         colorTable: [Int: VectorColor] = [:], widthTable: [Int: Double] = [:], gradientTable: [Int: GradientInfo] = [:]) -> VectorShape? {
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

        let (fillStyle, strokeStyle) = extractFillStroke(data: data, recordOffset: recordOffset,
                                                          colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable, isClosed: true)

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
