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
        let colors: [VectorColor]
        // Legacy convenience init
        init(type: GradientType = .linear, colors: [VectorColor]) {
            self.type = type; self.colors = colors
        }
        init(color1: VectorColor, color2: VectorColor) {
            self.type = .linear; self.colors = [color1, color2]
        }
    }

    private static func buildColorAndWidthTables(data: Data) -> ([Int: VectorColor], [Int: Double], [Int: GradientInfo]) {
        var colorTable: [Int: VectorColor] = [:]
        var widthTable: [Int: Double] = [:]
        var gradientTable: [Int: GradientInfo] = [:]

        // Read starting child ID from first TABLE (0x0005) record. Also pull
        // the full child-ID list — those are the FH2-native slot IDs for the
        // document's first N declared styles/colors (e.g. ungroup.fh2 lists
        // [36, 37, 38] meaning rid 36=black, 37=purple, 38=peach). 14B5
        // style records' innerRef values reference these slot IDs directly.
        var firstChildID = 18
        var tableChildIDs: [Int] = []
        for i in stride(from: headerSize, to: min(data.count - 10, headerSize + 2000), by: 1) {
            guard i + 6 <= data.count else { break }
            if readUInt16BE(data, offset: i + 2) == 0x0005 {
                let size = Int(readUInt16BE(data, offset: i))
                if size >= 16 && size < 200 {
                    let count = Int(readUInt16BE(data, offset: i + 4))
                    if count > 0 && i + 10 < data.count {
                        firstChildID = Int(readUInt16BE(data, offset: i + 10))
                        // Grab up to `count` child IDs from +10 onwards.
                        for k in 0..<count {
                            let off = i + 10 + k * 2
                            guard off + 2 <= data.count, off + 2 <= i + size else { break }
                            tableChildIDs.append(Int(readUInt16BE(data, offset: off)))
                        }
                    }
                    break
                }
            }
        }

        // Scan EVERY plausible record by byte-walking. Each style/color record
        // gets TWO IDs:
        //   - styleRid: firstChildID + index-among-styles-only (matches what
        //     style records' innerRef points at — black at firstChildID, etc).
        //   - globalRid: byte-walk seq (matches what path records' fillRef
        //     indexes into — the file's true global ID space).
        // We store the color at both IDs in colorTable so both lookup paths work.
        var allRecords: [(offset: Int, type: UInt16, styleRid: Int, globalRid: Int)] = []
        var offset = headerSize
        var globalSeq = firstChildID
        var styleIdx = 0
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            var matched = false
            // Color records
            if (rtype == 0x1452 && size == 30) ||
               (rtype == 0x1453 && size == 30) ||
               (rtype == 0x1454 && size == 32 && offset + 22 <= data.count) {
                allRecords.append((offset, rtype, firstChildID + styleIdx, globalSeq))
                styleIdx += 1
                matched = true
            }
            // Style/attribute records
            else if (rtype >= 0x14B0 && rtype <= 0x14FF && size >= 10 && size <= 100) ||
                    (rtype == 0x157D && size >= 10 && size <= 100) {
                allRecords.append((offset, rtype, firstChildID + styleIdx, globalSeq))
                styleIdx += 1
                matched = true
            }
            // Other record types we don't index but still consume a global slot.
            else if (rtype == 0x1389 && size == 56) ||
                    (rtype == 0x0005 && size >= 16 && size < 300) ||
                    (rtype == 0x138A && size >= 20 && size <= 200) ||
                    (rtype == 0x151C && size >= 44 && offset + size <= data.count
                        && offset + 30 <= data.count
                        && size == 44 + Int(readUInt16BE(data, offset: offset + 28)) * 16) ||
                    (rtype == 0x1519 && size == 60) ||
                    (rtype == 0x151A && size == 56) ||
                    (rtype == 0x151D && size == 48) ||
                    (rtype == 0x13ED && size == 56) ||
                    (rtype == 0x13EE) ||
                    (rtype == 0x12C0 && size == 32) {
                matched = true
            }
            if matched { globalSeq += 1 }
            offset += 1
        }

        // Extract data using BOTH rids recorded during the scan.
        for rec in allRecords {
            let rid = rec.styleRid
            let gid = rec.globalRid
            let off = rec.offset

            // Color extraction — store at both styleRid (for innerRef chain) and
            // globalRid (for path's fillRef).
            func storeColor(_ color: VectorColor) {
                colorTable[rid] = color
                colorTable[gid] = color
                let eid = Int(readUInt16BE(data, offset: off + 4))
                if eid > 0 { colorTable[eid] = color }
            }
            if rec.type == 0x1452 || rec.type == 0x1453 {
                let r = Double(readUInt16BE(data, offset: off + 6)) / 65535.0
                let g = Double(readUInt16BE(data, offset: off + 8)) / 65535.0
                let b = Double(readUInt16BE(data, offset: off + 10)) / 65535.0
                storeColor(VectorColor.rgb(RGBColor(red: r, green: g, blue: b)))
            } else if rec.type == 0x1454 {
                let c = Double(readUInt16BE(data, offset: off + 14)) / 65535.0
                let m = Double(readUInt16BE(data, offset: off + 16)) / 65535.0
                let y = Double(readUInt16BE(data, offset: off + 18)) / 65535.0
                let k = Double(readUInt16BE(data, offset: off + 20)) / 65535.0
                let r = (1 - c) * (1 - k); let g = (1 - m) * (1 - k); let b = (1 - y) * (1 - k)
                storeColor(VectorColor.rgb(RGBColor(red: r, green: g, blue: b)))
            }

            // Style: follow inner_ref (uses styleRid scheme) to color, then
            // mirror the resolved color into both rid AND gid slots.
            if rec.type >= 0x14B0 && off + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: off + 10))

                if rec.type == 0x14B8 && innerRef > 0 {
                    if let edgeColor = colorTable[innerRef] {
                        gradientTable[rid] = GradientInfo(type: .radial, colors: [.white, edgeColor])
                        gradientTable[gid] = GradientInfo(type: .radial, colors: [.white, edgeColor])
                        colorTable[rid] = edgeColor
                        colorTable[gid] = edgeColor
                    }
                } else if rec.type == 0x14B7 && off + 14 <= data.count {
                    let ref2 = Int(readUInt16BE(data, offset: off + 12))
                    if let c1 = colorTable[innerRef], let c2 = colorTable[ref2] {
                        gradientTable[rid] = GradientInfo(color1: c2, color2: c1)
                        gradientTable[gid] = GradientInfo(color1: c2, color2: c1)
                        colorTable[rid] = c1
                        colorTable[gid] = c1
                    }
                } else if innerRef > 0, let color = colorTable[innerRef] {
                    colorTable[rid] = color
                    colorTable[gid] = color
                } else if innerRef == 0 {
                    if let black = colorTable[firstChildID] {
                        colorTable[rid] = black
                        colorTable[gid] = black
                    }
                }
            }

            // SB (0x14B6): stroke width at +18
            if rec.type == 0x14B6 && off + 20 <= data.count {
                let rawWidth = Int(readUInt16BE(data, offset: off + 18))
                if rawWidth > 0 {
                    widthTable[rid] = Double(rawWidth) / 10.0
                    widthTable[gid] = Double(rawWidth) / 10.0
                }
            }
        }

        // Bind document-declared color slots from the first TABLE record.
        // ungroup.fh2: tableChildIDs = [36, 37, 38] maps to [black, purple,
        // peach] based on file order of the first 3 color records. Path
        // styles reference these slot IDs via innerRef, so populate them.
        let colorRecords = allRecords
            .filter { $0.type == 0x1452 || $0.type == 0x1453 || $0.type == 0x1454 }
            .prefix(tableChildIDs.count)
        for (slotID, colorRec) in zip(tableChildIDs, colorRecords) {
            let off = colorRec.offset
            if colorRec.type == 0x1454 {
                let c = Double(readUInt16BE(data, offset: off + 14)) / 65535.0
                let m = Double(readUInt16BE(data, offset: off + 16)) / 65535.0
                let y = Double(readUInt16BE(data, offset: off + 18)) / 65535.0
                let k = Double(readUInt16BE(data, offset: off + 20)) / 65535.0
                let r = (1 - c) * (1 - k); let g = (1 - m) * (1 - k); let b = (1 - y) * (1 - k)
                colorTable[slotID] = .rgb(RGBColor(red: r, green: g, blue: b))
            } else {
                let r = Double(readUInt16BE(data, offset: off + 6)) / 65535.0
                let g = Double(readUInt16BE(data, offset: off + 8)) / 65535.0
                let b = Double(readUInt16BE(data, offset: off + 10)) / 65535.0
                colorTable[slotID] = .rgb(RGBColor(red: r, green: g, blue: b))
            }
        }

        return (colorTable, widthTable, gradientTable)
    }

    // MARK: - Layer Parsing

    /// Parse 0x138A records into layer → [shapeID] mapping
    /// For each 0x138A group record, find the adjacent 0x14B5 style record
    /// batch and map every listed shape absID → that batch's color. Solves
    /// the "per-shape color is wrong" problem: FH2 stores shapes in a
    /// different file order than the style records that apply to them, so
    /// looking up fillRef in isolation assigns the wrong color at batch
    /// boundaries. Group membership is the authoritative source.
    private static func parseGroupColorsByAbsID(data: Data,
                                                 colorTable: [Int: VectorColor]) -> [Int: VectorColor] {
        var result: [Int: VectorColor] = [:]
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            guard rtype == 0x138A, size >= 20, size <= 200,
                  offset + size <= data.count,
                  offset + 34 <= data.count else {
                offset += 1
                continue
            }
            // Count + IDs live at +32 in every shape-carrying 0x138A we've seen.
            let count = Int(readUInt16BE(data, offset: offset + 32))
            guard count > 0, count < 100, offset + 34 + count * 2 <= data.count else {
                offset += 1
                continue
            }
            var shapeIDs: [Int] = []
            for i in 0..<count {
                let id = Int(readUInt16BE(data, offset: offset + 34 + i * 2))
                if id > 0 { shapeIDs.append(id) }
            }
            guard !shapeIDs.isEmpty else {
                offset += 1
                continue
            }
            // Find the next 0x14B5 style record following this 138A and
            // resolve its innerRef to a color. All members of this group
            // share that color (FH2 style batches are uniform per group).
            if let groupColor = scanForwardForStyleColor(data: data,
                                                         startOffset: offset + size,
                                                         colorTable: colorTable) {
                for id in shapeIDs { result[id] = groupColor }
            }
            offset += 1
        }
        return result
    }

    private static func parseLayers(data: Data) -> [[Int]] {
        var layers: [[Int]] = []
        var offset = headerSize
        while offset + 4 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            if rtype == 0x138A && size >= 20 && size <= 200 {
                // Read values after 6-byte header
                var vals: [Int] = []
                var j = offset + 6
                while j + 1 < offset + size && j + 1 < data.count {
                    vals.append(Int(readUInt16BE(data, offset: j)))
                    j += 2
                }
                // Find count + child IDs: first non-zero value after header zeros (skip '16')
                var children: [Int] = []
                for (idx, v) in vals.enumerated() {
                    if idx > 0 && v > 0 && v != 16 && v < 10000 {
                        let count = v
                        for k in (idx+1)..<min(idx+1+count, vals.count) {
                            if vals[k] > 0 { children.append(vals[k]) }
                        }
                        break
                    }
                }
                if !children.isEmpty {
                    layers.append(children)
                }
            }
            offset += 1
        }
        return layers
    }

    // MARK: - Positional Style→Path Mapping
    //
    // Empirical pattern from ungroup.fh2 / torfont.fh2: the 0x14B5 style
    // records that apply to paths are stored in FILE ORDER matching the path
    // records they style — path[N] ↔ (path-style)[N]. "Path styles" are
    // 14B5 records whose innerRef resolves to one of the document's named
    // colors (i.e. innerRef == firstChildID+k for some k in the color table).
    // Setup-phase 14B5 records with innerRef=0 or pointing at non-color
    // records are skipped.
    //
    // Returns [pathIndex: VectorColor], applied as a post-pass override.
    private static func parsePathStylesByPosition(data: Data,
                                                   pathCount: Int,
                                                   colorTable: [Int: VectorColor])
        -> [Int: VectorColor]
    {
        // Collect 14B5 style records that look like path styles. A path style
        // has a non-zero innerRef that resolves to a known color.
        var pathStyleColors: [VectorColor] = []
        var offset = headerSize
        while offset + 22 <= data.count {
            let size = Int(readUInt16BE(data, offset: offset))
            let rtype = readUInt16BE(data, offset: offset + 2)
            if rtype == 0x14B5, size >= 10, size <= 100,
               offset + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: offset + 10))
                if innerRef > 0, let color = colorTable[innerRef] {
                    pathStyleColors.append(color)
                }
            }
            offset += 1
        }

        // The last `pathCount` path-styles are the ones that matter — setup
        // styles come before the batch that styles the drawing's paths.
        guard pathStyleColors.count >= pathCount else {
            // Not enough styles to pair 1:1, fall back to forward-scan logic.
            return [:]
        }
        let startIdx = pathStyleColors.count - pathCount
        var result: [Int: VectorColor] = [:]
        for i in 0..<pathCount {
            result[i] = pathStyleColors[startIdx + i]
        }
        return result
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

        // Parse layer definitions (0x138A records → child shape ID lists)
        let layerShapeIDs = parseLayers(data: data)

        // Authoritative per-shape color from 0x138A groups + adjacent 0x14B5
        // style batches. Overrides whatever fillRef lookup produced.
        let groupColorByAbsID = parseGroupColorsByAbsID(data: data, colorTable: colorTable)

        // Pre-scan: build offset → absID map (count all records except 0x138A, starting at DOC=2)
        var offsetToAbsID: [Int: Int] = [:]
        var preAbsID = 2
        var preOff = headerSize
        while preOff + 4 <= data.count {
            let sz = Int(readUInt16BE(data, offset: preOff))
            let rt = readUInt16BE(data, offset: preOff + 2)
            var found = false
            // Match any known record type EXCEPT 0x138A
            if rt == 0x138A { /* skip */ }
            else if rt == 0x1389 && sz == 56 { found = true }
            else if rt == 0x0005 && sz >= 16 && sz < 300 { found = true }
            else if rt == pathRecordType && sz >= 44 && preOff + sz <= data.count && preOff + 29 < data.count {
                if sz == 44 + Int(readUInt16BE(data, offset: preOff + 28)) * 16 { found = true }
            }
            else if (rt == rectRecordType && sz == 60) || (rt == ovalRecordType && sz == 56) ||
                    (rt == lineRecordType && sz == 48) { found = true }
            else if (rt >= 0x1452 && rt <= 0x1454 && sz >= 30 && sz <= 32) { found = true }
            else if (rt >= 0x14B0 && rt <= 0x14FF && sz >= 10 && sz <= 100) { found = true }
            else if (rt == 0x157D && sz >= 10 && sz <= 100) { found = true }
            else if (rt == 0x13ED && sz == 56) { found = true }
            if found {
                offsetToAbsID[preOff] = preAbsID
                preAbsID += 1
            }
            preOff += 1
        }

        // Scan for shape records
        var shapes: [VectorShape] = []
        var shapeAbsIDs: [Int] = []
        var offset = headerSize

        while offset + 4 <= data.count {
            let word = readUInt16BE(data, offset: offset)
            let rtype = readUInt16BE(data, offset: offset + 2)

            // Look for a path record type at offset+2 (size at offset)
            if offset + 44 <= data.count {
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
                            shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                        }
                    }
                } else if rtype == ovalRecordType && word == 56 && offset + 40 <= data.count {
                    if let shape = parseOvalRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                    }
                } else if rtype == rectRecordType && word == 60 && offset + 44 <= data.count {
                    if let shape = parseRectRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                    }
                } else if rtype == lineRecordType && word == 48 && offset + 40 <= data.count {
                    if let shape = parseLineRecord(data: data, recordOffset: offset,
                                                    pageHeight: pageHeight,
                                                    colorTable: colorTable, widthTable: widthTable, gradientTable: gradientTable) {
                        shapes.append(shape)
                        shapeAbsIDs.append(offsetToAbsID[offset] ?? 0)
                    }
                }
            }

            // Records can overlap by design — always advance one byte so the
            // next record start isn't missed.
            offset += 1
        }

        guard !shapes.isEmpty else {
            throw FreeHandImportError.emptyOutput
        }

        // Override each shape's fill with the authoritative group color (from
        // 0x138A membership) when available. This corrects the per-path color
        // assignment at batch boundaries.
        if !groupColorByAbsID.isEmpty {
            for i in 0..<shapes.count {
                let absID = shapeAbsIDs[i]
                if let groupColor = groupColorByAbsID[absID] {
                    shapes[i].fillStyle = FillStyle(color: groupColor)
                }
            }
        }

        // Positional path→style pairing. For FH2 files where the 14B5 styles
        // that apply to the drawing are stored contiguously in file order and
        // there are exactly `shapes.count` of them (common in ungrouped
        // drawings), path[N] uses style[N]'s color. Runs AFTER the 138A
        // override so group-driven colors take precedence if both apply.
        let positionalColors = parsePathStylesByPosition(data: data,
                                                          pathCount: shapes.count,
                                                          colorTable: colorTable)
        if !positionalColors.isEmpty {
            for i in 0..<shapes.count {
                if groupColorByAbsID[shapeAbsIDs[i]] == nil,
                   let c = positionalColors[i] {
                    shapes[i].fillStyle = FillStyle(color: c)
                }
            }
        }

        // Build native InkPen Layers from 0x138A layer records. Each record lists absolute
        // shape IDs (pre-scan map); translate back to shape UUIDs.
        var nativeLayers: [Layer] = []
        if !layerShapeIDs.isEmpty {
            let absIDToShapeID: [Int: UUID] = Dictionary(uniqueKeysWithValues:
                zip(shapeAbsIDs, shapes.map { $0.id }).filter { $0.0 != 0 })
            for (layerIdx, absIDs) in layerShapeIDs.enumerated() {
                let objectIDs = absIDs.compactMap { absIDToShapeID[$0] }
                guard !objectIDs.isEmpty else { continue }
                nativeLayers.append(Layer(
                    name: "Layer \(layerIdx + 1)",
                    objectIDs: objectIDs,
                    isVisible: true,
                    isLocked: false,
                    opacity: 1.0,
                    blendMode: .normal,
                    color: .blue
                ))
            }
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
            stats: stats,
            layers: nativeLayers,
            groupShapeIDs: []
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
            // FH2 point order: (onCurve, controlIn, controlOut)
            let onCurve = CGPoint(
                x: x1 / unitsPerPoint,
                y: pageHeight - y1 / unitsPerPoint
            )
            let controlIn = CGPoint(
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

        // Determine if path is closed: check +26 flag OR first==last on-curve
        let filledFlag = readUInt16BE(data, offset: recordOffset + 26)
        let firstOnCurve = fh2Points[0].onCurve
        let lastOnCurve = fh2Points[fh2Points.count - 1].onCurve
        let pointsMatch = fh2Points.count > 1
            && abs(firstOnCurve.x - lastOnCurve.x) < 0.01
            && abs(firstOnCurve.y - lastOnCurve.y) < 0.01
        let isClosed = pointsMatch || filledFlag == 1

        // Convert FH2 points to path elements
        let elements = buildPathElements(from: fh2Points, closed: isClosed)
        guard !elements.isEmpty else { return nil }

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

    /// FreeHand writes the style records that apply to a batch of paths right
    /// after that batch. When a path's `fillRef` misses the color table, scan
    /// forward from the path's end for the next 0x14B5 style record and
    /// resolve via its innerRef → colorTable lookup. Capped at 2 KB to bound
    /// cost.
    private static func scanForwardForStyleColor(data: Data, startOffset: Int,
                                                  colorTable: [Int: VectorColor]) -> VectorColor? {
        let limit = min(startOffset + 2048, data.count - 4)
        var o = startOffset
        while o < limit {
            let size = Int(readUInt16BE(data, offset: o))
            let rtype = readUInt16BE(data, offset: o + 2)
            if rtype == 0x14B5, size >= 12, o + 12 <= data.count {
                let innerRef = Int(readUInt16BE(data, offset: o + 10))
                if innerRef > 0, let c = colorTable[innerRef] {
                    return c
                }
            }
            o += 1
        }
        return nil
    }

    private static func extractFillStroke(data: Data, recordOffset: Int,
                                           colorTable: [Int: VectorColor],
                                           widthTable: [Int: Double], gradientTable: [Int: GradientInfo] = [:],
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
            // Check gradient first
            if let grad = gradientTable[fillRef], grad.colors.count >= 2 {
                var stops: [GradientStop] = []
                for (idx, color) in grad.colors.enumerated() {
                    let pos = grad.colors.count > 1 ? Double(idx) / Double(grad.colors.count - 1) : 0
                    stops.append(GradientStop(position: pos, color: color))
                }
                switch grad.type {
                case .linear:
                    let linear = LinearGradient(startPoint: CGPoint(x: 0, y: 0.5), endPoint: CGPoint(x: 1, y: 0.5), stops: stops)
                    fillStyle = FillStyle(color: .gradient(.linear(linear)))
                case .radial:
                    let radial = RadialGradient(centerPoint: CGPoint(x: 0.5, y: 0.5), radius: 0.5, stops: stops)
                    fillStyle = FillStyle(color: .gradient(.radial(radial)))
                }
            } else if let fillColor = colorTable[fillRef] {
                fillStyle = FillStyle(color: fillColor)
            } else if let scanned = Self.scanForwardForStyleColor(data: data, startOffset: recordOffset + 44, colorTable: colorTable) {
                // When the fillRef doesn't resolve via the ID table, FreeHand's
                // file convention is that the style record with the intended
                // color follows shortly after the path. Scan forward for the
                // next 0x14B5 and use its innerRef.
                fillStyle = FillStyle(color: scanned)
            } else {
                // Final fallback: grayscale byte at +12.
                let fillGrayByte = data[recordOffset + 12]
                let fillGray = 1.0 - Double(fillGrayByte) / 127.0
                fillStyle = FillStyle(color: .rgb(RGBColor(red: fillGray, green: fillGray, blue: fillGray)))
            }
        }

        // Look up stroke color and width from tables.
        // FreeHand records strokeRef==0 for "no stroke" — don't invent a gray
        // fallback in that case (the EPS export for the same drawing has no
        // stroke either; inventing one was producing the light-grey outlines
        // that don't exist in the source).
        let strokeStyle: StrokeStyle?
        if strokeRef > 0, let strokeColor = colorTable[strokeRef] {
            let strokeWidth = widthTable[strokeRef] ?? 0.5
            strokeStyle = StrokeStyle(color: strokeColor, width: strokeWidth)
        } else {
            strokeStyle = nil
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

    private static func buildPathElements(from points: [FH2Point], closed: Bool = false) -> [PathElement] {
        guard let first = points.first else { return [] }

        var elements: [PathElement] = []
        elements.reserveCapacity(points.count + 1) // +1 for potential close

        // First point is always a moveTo
        elements.append(.move(to: VectorPoint(first.onCurve.x, first.onCurve.y)))

        let segmentCount = points.count - 1

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

        if closed {
            // Add closing curve segment from last point back to first
            let last = points[points.count - 1]
            let prevOutCoincident = abs(last.controlOut.x - last.onCurve.x) < 0.01
                && abs(last.controlOut.y - last.onCurve.y) < 0.01
            let nextInCoincident = abs(first.controlIn.x - first.onCurve.x) < 0.01
                && abs(first.controlIn.y - first.onCurve.y) < 0.01
            if prevOutCoincident && nextInCoincident {
                elements.append(.line(to: VectorPoint(first.onCurve.x, first.onCurve.y)))
            } else {
                elements.append(.curve(
                    to: VectorPoint(first.onCurve.x, first.onCurve.y),
                    control1: VectorPoint(last.controlOut.x, last.controlOut.y),
                    control2: VectorPoint(first.controlIn.x, first.controlIn.y)
                ))
            }
            elements.append(.close)
        }

        return elements
    }
}
