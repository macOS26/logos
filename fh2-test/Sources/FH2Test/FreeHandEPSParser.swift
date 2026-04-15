import Foundation
import CoreGraphics

/// Parses FreeHand-exported EPS files into VectorShapes
enum FreeHandEPSParser {

    static func parseToShapes(data: Data) throws -> FreeHandDirectImporter.Result {
        guard let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8),
              text.hasPrefix("%!PS-Adobe") else {
            throw FreeHandImportError.notSupported
        }

        // Extract BoundingBox for page dimensions and origin offset
        var pageWidth: Double = 612
        var pageHeight: Double = 792
        var bbOriginX: Double = 0
        var bbOriginY: Double = 0
        if let bbRange = text.range(of: "%%BoundingBox:") {
            let bbLine = text[bbRange.upperBound...]
            let nums = bbLine.prefix(100)
                .split { $0 == " " || $0 == "\n" || $0 == "\r" || $0 == "%" }
                .prefix(4)
                .compactMap { Double($0) }
            if nums.count >= 4 {
                bbOriginX = nums[0]
                bbOriginY = nums[1]
                pageWidth = nums[2] - nums[0]
                pageHeight = nums[3] - nums[1]
                print("BBox: \(nums) → page \(pageWidth)×\(pageHeight) origin (\(bbOriginX),\(bbOriginY))")
            }
        }

        // Normalize line endings (FH2 EPS uses CR \r not LF \n)
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")

        // Find drawing commands: search for "]def" then "vms" after it
        guard let defRange = normalized.range(of: "]def") else {
            throw FreeHandImportError.parseFailed(code: 1)
        }
        let afterDef = normalized[defRange.upperBound...]
        guard let vmsRange = afterDef.range(of: "vms") else {
            throw FreeHandImportError.parseFailed(code: 2)
        }
        let drawingText = String(afterDef[vmsRange.upperBound...])

        // Tokenize and parse
        // Debug: show first 30 tokens
        let debugTokens = tokenize(drawingText)
        print("Drawing text length: \(drawingText.count)")
        print("Token count: \(debugTokens.count)")
        print("First 30 tokens: \(debugTokens.prefix(30))")
        // Show tokens 155-175 (gradient area)
        if debugTokens.count > 175 {
            print("Tokens 155-175: \(Array(debugTokens[155..<175]))")
        }

        let rawShapes = parsePostScript(drawingText, pageHeight: pageHeight, originX: bbOriginX, originY: bbOriginY)

        // Merge consecutive fill+stroke pairs that share the same path into single shapes
        let shapes = mergeFillStrokePairs(rawShapes)
        print("Shapes: \(rawShapes.count) raw → \(shapes.count) merged")

        guard !shapes.isEmpty else {
            throw FreeHandImportError.emptyOutput
        }

        let stats = FreeHandDirectImporter.Stats(
            paths: shapes.count, groups: 0, clipGroups: 0,
            compositePaths: 0, newBlends: 0, symbolInstances: 0, contentIdPaths: 0
        )

        return FreeHandDirectImporter.Result(
            shapes: shapes,
            pageSize: CGSize(width: pageWidth, height: pageHeight),
            stats: stats
        )
    }

    // MARK: - PostScript Parser

    private struct Transform {
        var a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, tx: Double = 0, ty: Double = 0

        func apply(_ x: Double, _ y: Double) -> (Double, Double) {
            (a * x + c * y + tx, b * x + d * y + ty)
        }

        func concat(_ other: Transform) -> Transform {
            Transform(
                a: a * other.a + c * other.b,
                b: b * other.a + d * other.b,
                c: a * other.c + c * other.d,
                d: b * other.c + d * other.d,
                tx: a * other.tx + c * other.ty + tx,
                ty: b * other.tx + d * other.ty + ty
            )
        }
    }

    private struct GraphicsState {
        var fillColor: VectorColor = .black
        var strokeColor: VectorColor = .black
        var lineWidth: Double = 1.0
        var transform: Transform = Transform()
    }

    private static func parsePostScript(_ text: String, pageHeight: Double, originX: Double = 0, originY: Double = 0) -> [VectorShape] {
        var shapes: [VectorShape] = []
        var stack: [Double] = []
        var elements: [PathElement] = []
        var state = GraphicsState()
        var stateStack: [GraphicsState] = []
        var currentColor: VectorColor = .black
        var pendingGradient: (color1: VectorColor, color2: VectorColor)? = nil

        // Simple tokenizer — split on whitespace, handle [] arrays
        let tokens = tokenize(text)
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            switch token {
            case "moveto":
                if stack.count >= 2 {
                    let y = stack.removeLast(); let x = stack.removeLast()
                    let (px, py) = state.transform.apply(x, y)
                    elements.append(.move(to: VectorPoint(px - originX, (originY + pageHeight) - py)))
                }

            case "lineto":
                if stack.count >= 2 {
                    let y = stack.removeLast(); let x = stack.removeLast()
                    let (px, py) = state.transform.apply(x, y)
                    elements.append(.line(to: VectorPoint(px - originX, (originY + pageHeight) - py)))
                }

            case "curveto":
                if stack.count >= 6 {
                    let y3 = stack.removeLast(); let x3 = stack.removeLast()
                    let y2 = stack.removeLast(); let x2 = stack.removeLast()
                    let y1 = stack.removeLast(); let x1 = stack.removeLast()
                    let (px1, py1) = state.transform.apply(x1, y1)
                    let (px2, py2) = state.transform.apply(x2, y2)
                    let (px3, py3) = state.transform.apply(x3, y3)
                    elements.append(.curve(
                        to: VectorPoint(px3 - originX, (originY + pageHeight) - py3),
                        control1: VectorPoint(px1 - originX, (originY + pageHeight) - py1),
                        control2: VectorPoint(px2 - originX, (originY + pageHeight) - py2)
                    ))
                }

            case "closepath":
                elements.append(.close)

            case "newpath":
                elements = []

            case "concat":
                // Apply transform matrix from stack: [a b c d tx ty]
                if stack.count >= 6 {
                    let ty = stack.removeLast(); let tx = stack.removeLast()
                    let dd = stack.removeLast(); let cc = stack.removeLast()
                    let bb = stack.removeLast(); let aa = stack.removeLast()
                    let newT = Transform(a: aa, b: bb, c: cc, d: dd, tx: tx, ty: ty)
                    state.transform = state.transform.concat(newT)
                }

            case "vms":
                // FreeHand save — often follows concat. Reset stack for drawing.
                stack.removeAll()

            case "gsave":
                stateStack.append(state)

            case "grestore":
                if let saved = stateStack.popLast() {
                    state = saved
                }

            case "setlinewidth":
                if let w = stack.popLast() {
                    state.lineWidth = w
                }

            case "setcolor":
                // Color was set by [C M Y K] before this token
                currentColor = state.fillColor

            case "setcmykcolor":
                if stack.count >= 4 {
                    let k = stack.removeLast(); let y = stack.removeLast()
                    let m = stack.removeLast(); let c = stack.removeLast()
                    let color = cmykToColor(c, m, y, k)
                    state.fillColor = color
                    state.strokeColor = color
                    currentColor = color
                }

            case "radialfill", "eoradialfill":
                // Radial gradient: stack has x y radius, pendingGradient has colors
                if let grad = pendingGradient, !elements.isEmpty {
                    // Read center and radius from stack (in page coordinates)
                    var cx = 0.5, cy = 0.5, rad = 0.5
                    if stack.count >= 3 {
                        rad = stack.removeLast()
                        let rawY = stack.removeLast()
                        let rawX = stack.removeLast()
                        let (tcx, tcy) = state.transform.apply(rawX, rawY)
                        cx = tcx - originX
                        cy = pageHeight - (tcy - originY)
                    }
                    let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
                    let stop1 = GradientStop(position: 0, color: grad.color2)
                    let stop2 = GradientStop(position: 1, color: grad.color1)
                    let radial = RadialGradient(
                        centerPoint: CGPoint(x: cx, y: cy),
                        radius: rad,
                        stops: [stop1, stop2]
                    )
                    let fillStyle = FillStyle(color: .gradient(.radial(radial)))
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                    pendingGradient = nil
                }
                stack.removeAll()

            case "rectfill":
                print("RECTFILL: pendingGradient=\(pendingGradient != nil) elements=\(elements.count)")
                if let grad = pendingGradient, !elements.isEmpty {
                    let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
                    let stop1 = GradientStop(position: 0, color: grad.color2)
                    let stop2 = GradientStop(position: 1, color: grad.color1)
                    let linear = LinearGradient(
                        startPoint: CGPoint(x: 0, y: 0.5),
                        endPoint: CGPoint(x: 1, y: 0.5),
                        stops: [stop1, stop2]
                    )
                    let fillStyle = FillStyle(color: .gradient(.linear(linear)))
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                    pendingGradient = nil
                }
                stack.removeAll()

            case "{fill}", "{ fill }", "{fill }", "{ fill}":
                if !elements.isEmpty {
                    let isClosed = elements.last.map { if case .close = $0 { return true } else { return false } } ?? false
                    let path = VectorPath(elements: elements, isClosed: isClosed, fillRule: .winding)
                    let fillStyle = FillStyle(color: currentColor)
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                }

            case "{stroke}", "{ stroke }", "{stroke }", "{ stroke}":
                if !elements.isEmpty {
                    let isClosed = elements.last.map { if case .close = $0 { return true } else { return false } } ?? false
                    let path = VectorPath(elements: elements, isClosed: isClosed, fillRule: .winding)
                    let strokeStyle = StrokeStyle(color: currentColor, width: state.lineWidth)
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: strokeStyle, fillStyle: nil, opacity: 1.0
                    ))
                    elements = []
                }

            default:
                // Try to parse as number
                if let num = Double(token) {
                    stack.append(num)
                }
                // Array: [N N N ...] — 4 numbers = CMYK color, 6 numbers = transform matrix.
                else if token.hasPrefix("[") {
                    var nums: [Double] = []
                    var t = token.dropFirst() // remove [
                    if t.hasSuffix("]") { t = t.dropLast() }
                    if let n = Double(t) { nums.append(n) }

                    var j = i + 1
                    while j < tokens.count {
                        var tk = tokens[j]
                        if tk.hasSuffix("]") {
                            tk = String(tk.dropLast())
                            if let n = Double(tk) { nums.append(n) }
                            j += 1
                            break
                        }
                        if let n = Double(tk) { nums.append(n) }
                        j += 1
                    }
                    i = j - 1

                    if nums.count == 6 {
                        // Transform matrix — push to stack so following `concat` / `makesetfont` can use it.
                        stack.append(contentsOf: nums)
                    } else if nums.count == 4 {
                        let color = cmykToColor(nums[0], nums[1], nums[2], nums[3])
                        currentColor = color
                        state.fillColor = color
                        state.strokeColor = color

                        // Check if next color array follows (gradient)
                        if j < tokens.count && tokens[j].hasPrefix("[") {
                            // This might be a gradient — save first color
                            let firstColor = color
                            // Parse second color array
                            var color2Nums: [Double] = []
                            var tk2 = tokens[j].dropFirst()
                            if tk2.hasSuffix("]") { tk2 = tk2.dropLast() }
                            if let n = Double(tk2) { color2Nums.append(n) }
                            var k = j + 1
                            while k < tokens.count {
                                var tkk = tokens[k]
                                if tkk.hasSuffix("]") {
                                    tkk = String(tkk.dropLast())
                                    if let n = Double(tkk) { color2Nums.append(n) }
                                    k += 1
                                    break
                                }
                                if let n = Double(tkk) { color2Nums.append(n) }
                                k += 1
                            }
                            if color2Nums.count == 4 {
                                let secondColor = cmykToColor(color2Nums[0], color2Nums[1], color2Nums[2], color2Nums[3])
                                pendingGradient = (firstColor, secondColor)
                                i = k - 1
                            }
                        }
                    }
                }
            }
            i += 1
        }

        return shapes
    }

    // MARK: - Merge Fill+Stroke Pairs

    private static func mergeFillStrokePairs(_ shapes: [VectorShape]) -> [VectorShape] {
        var merged: [VectorShape] = []
        var i = 0
        while i < shapes.count {
            let current = shapes[i]
            // Check if next shape has the same path and complements fill/stroke
            if i + 1 < shapes.count {
                let next = shapes[i + 1]
                let samePath = current.path.elements.count == next.path.elements.count
                if samePath && current.fillStyle != nil && current.strokeStyle == nil
                    && next.fillStyle == nil && next.strokeStyle != nil {
                    // Merge: fill from current, stroke from next
                    merged.append(VectorShape(
                        name: current.name, path: current.path,
                        geometricType: current.geometricType,
                        strokeStyle: next.strokeStyle,
                        fillStyle: current.fillStyle,
                        opacity: current.opacity
                    ))
                    i += 2
                    continue
                }
            }
            merged.append(current)
            i += 1
        }
        return merged
    }

    // MARK: - Helpers

    private static func cmykToColor(_ c: Double, _ m: Double, _ y: Double, _ k: Double) -> VectorColor {
        let r = (1 - c) * (1 - k)
        let g = (1 - m) * (1 - k)
        let b = (1 - y) * (1 - k)
        return .rgb(RGBColor(red: r, green: g, blue: b))
    }

    private static func tokenize(_ text: String) -> [String] {
        // Pre-process: add spaces around PostScript keywords so they tokenize correctly
        // even when concatenated without whitespace (common in FreeHand EPS)
        // Order matters: longer keywords first to avoid partial matches
        let keywords = ["rectfill","eoclip","closepath","moveto","lineto","curveto",
                        "newpath","gsave","grestore","setlinewidth","setcolor","setcmykcolor",
                        "setlinecap","setlinejoin","setmiterlimit","eofill","setflat",
                        "concat","stroke","fill","clip","def","vms","vmr","end"]
        var processed = text
        // Protect compound keywords first by using placeholders
        processed = processed.replacingOccurrences(of: "eoradialfill", with: " §EORADIALFILL§ ")
        processed = processed.replacingOccurrences(of: "radialfill", with: " §RADIALFILL§ ")
        processed = processed.replacingOccurrences(of: "rectfill", with: " §RECTFILL§ ")
        processed = processed.replacingOccurrences(of: "eofill", with: " §EOFILL§ ")
        processed = processed.replacingOccurrences(of: "eoclip", with: " §EOCLIP§ ")
        for kw in keywords {
            if kw == "rectfill" || kw == "eofill" || kw == "eoclip" { continue }
            processed = processed.replacingOccurrences(of: kw, with: " \(kw) ")
        }
        // Restore compound keywords
        processed = processed.replacingOccurrences(of: "§EORADIALFILL§", with: "eoradialfill")
        processed = processed.replacingOccurrences(of: "§RADIALFILL§", with: "radialfill")
        processed = processed.replacingOccurrences(of: "§RECTFILL§", with: "rectfill")
        processed = processed.replacingOccurrences(of: "§EOFILL§", with: "eofill")
        processed = processed.replacingOccurrences(of: "§EOCLIP§", with: "eoclip")
        // Also split around [ and ]
        processed = processed.replacingOccurrences(of: "[", with: " [")
        processed = processed.replacingOccurrences(of: "]", with: "] ")

        var tokens: [String] = []
        var current = ""
        var inBrace = 0

        for ch in processed {
            if ch == "{" {
                inBrace += 1
                current.append(ch)
            } else if ch == "}" {
                current.append(ch)
                inBrace -= 1
                if inBrace == 0 {
                    tokens.append(current)
                    current = ""
                }
            } else if inBrace > 0 {
                current.append(ch)
            } else if ch == " " || ch == "\n" || ch == "\r" || ch == "\t" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
