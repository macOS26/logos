import Foundation
import CoreGraphics

/// Parses FreeHand-exported EPS files into VectorShapes
enum FreeHandEPSParser {

    static func parseToShapes(data: Data) throws -> FreeHandDirectImporter.Result {
        guard let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8),
              text.hasPrefix("%!PS-Adobe") else {
            throw FreeHandImportError.notSupported
        }

        // Extract BoundingBox for page dimensions
        var pageWidth: Double = 612
        var pageHeight: Double = 792
        if let bbRange = text.range(of: "%%BoundingBox:") {
            let bbLine = text[bbRange.upperBound...]
            let nums = bbLine.prefix(100).split(separator: " ").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if nums.count >= 4 {
                pageWidth = nums[2] - nums[0]
                pageHeight = nums[3] - nums[1]
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
        let shapes = parsePostScript(drawingText, pageHeight: pageHeight)

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

    private struct GraphicsState {
        var fillColor: VectorColor = .black
        var strokeColor: VectorColor = .black
        var lineWidth: Double = 1.0
    }

    private static func parsePostScript(_ text: String, pageHeight: Double) -> [VectorShape] {
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
                    let y = stack.removeLast()
                    let x = stack.removeLast()
                    elements.append(.move(to: VectorPoint(x, pageHeight - y)))
                }

            case "lineto":
                if stack.count >= 2 {
                    let y = stack.removeLast()
                    let x = stack.removeLast()
                    elements.append(.line(to: VectorPoint(x, pageHeight - y)))
                }

            case "curveto":
                if stack.count >= 6 {
                    let y3 = stack.removeLast(); let x3 = stack.removeLast()
                    let y2 = stack.removeLast(); let x2 = stack.removeLast()
                    let y1 = stack.removeLast(); let x1 = stack.removeLast()
                    elements.append(.curve(
                        to: VectorPoint(x3, pageHeight - y3),
                        control1: VectorPoint(x1, pageHeight - y1),
                        control2: VectorPoint(x2, pageHeight - y2)
                    ))
                }

            case "closepath":
                elements.append(.close)

            case "newpath":
                elements = []

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

            case "rectfill", "rectfillgrestore", "rectfillgrestoregsave1":
                // Gradient: preceding tokens had two color arrays and parameters
                if let grad = pendingGradient {
                    if !elements.isEmpty {
                        let path = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
                        let stop1 = GradientStop(position: 0, color: grad.color1)
                        let stop2 = GradientStop(position: 1, color: grad.color2)
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
                    }
                    pendingGradient = nil
                }

            case "{fill}":
                if !elements.isEmpty {
                    let isClosed = elements.last.map { if case .close = $0 { return true } else { return false } } ?? false
                    let path = VectorPath(elements: elements, isClosed: isClosed, fillRule: .winding)
                    let fillStyle = FillStyle(color: currentColor)
                    shapes.append(VectorShape(
                        name: "Path", path: path, geometricType: nil,
                        strokeStyle: nil, fillStyle: fillStyle, opacity: 1.0
                    ))
                }

            case "{stroke}":
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
                // Check for CMYK array: [C M Y K]
                else if token.hasPrefix("[") {
                    // Parse color array [C M Y K]
                    var colorNums: [Double] = []
                    var t = token.dropFirst() // remove [
                    if t.hasSuffix("]") { t = t.dropLast() }
                    if let n = Double(t) { colorNums.append(n) }

                    var j = i + 1
                    while j < tokens.count {
                        var tk = tokens[j]
                        if tk.hasSuffix("]") {
                            tk = String(tk.dropLast())
                            if let n = Double(tk) { colorNums.append(n) }
                            j += 1
                            break
                        }
                        if let n = Double(tk) { colorNums.append(n) }
                        j += 1
                    }
                    i = j - 1

                    if colorNums.count == 4 {
                        let color = cmykToColor(colorNums[0], colorNums[1], colorNums[2], colorNums[3])
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
        let keywords = ["moveto","lineto","curveto","closepath","newpath","gsave","grestore",
                        "setlinewidth","setcolor","setcmykcolor","setlinecap","setlinejoin",
                        "setmiterlimit","fill","stroke","rectfill","eofill","clip","eoclip",
                        "setflat","def","vms","vmr","end"]
        var processed = text
        for kw in keywords {
            processed = processed.replacingOccurrences(of: kw, with: " \(kw) ")
        }
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
