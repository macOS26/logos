import Foundation

@main
struct FH2Test {
    static func main() {
        let path = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "/Users/toddbruss/Downloads/simple.fh2"

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("Cannot read: \(path)")
            return
        }

        print("File: \(path) (\(data.count) bytes)")

        do {
            // Auto-detect format: EPS (text) or FH2 (binary)
            let isEPS = data.count > 10 && String(data: data.prefix(10), encoding: .ascii)?.hasPrefix("%!PS") == true
            let result = try isEPS
                ? FreeHandEPSParser.parseToShapes(data: data)
                : FreeHand2Parser.parseToShapes(data: data)
            if isEPS { print("Format: EPS") } else { print("Format: FH2") }
            print("Parsed: \(result.shapes.count) shapes, page \(Int(result.pageSize.width))×\(Int(result.pageSize.height))")

            // Get gradient info for SVG generation
            let gradients = FreeHand2Parser.debugGradientTable(data: data)

            // Generate SVG
            let svg = generateSVG(shapes: result.shapes, pageSize: result.pageSize, data: data, gradients: gradients)
            let outPath = path.replacingOccurrences(of: ".fh2", with: "_parsed.svg")
                .replacingOccurrences(of: ".fh", with: "_parsed.svg")
            try svg.write(toFile: outPath, atomically: true, encoding: .utf8)
            print("SVG written: \(outPath)")

            // Scan for ALL record types between colors and styles
            print("\nAll records in file (type 0x1000-0x1FFF):")
            var scanOff = 256
            while scanOff + 4 <= data.count {
                let sz = Int(data[data.startIndex+scanOff]) << 8 | Int(data[data.startIndex+scanOff+1])
                let rt = Int(data[data.startIndex+scanOff+2]) << 8 | Int(data[data.startIndex+scanOff+3])
                if rt >= 0x1400 && rt < 0x1600 && sz >= 10 && sz <= 100 {
                    let eid = (scanOff + 6 <= data.count) ? (Int(data[data.startIndex+scanOff+4]) << 8 | Int(data[data.startIndex+scanOff+5])) : 0
                    print(String(format: "  @0x%04X size=%2d type=0x%04X eid=%d", scanOff, sz, rt, eid))
                }
                scanOff += 1
            }

            // Print color table debug info
            print("\nColor table entries:")
            let (ct, wt) = FreeHand2Parser.debugColorTable(data: data)
            for id in ct.keys.sorted() {
                let (r,g,b) = ct[id]!.rgbValues
                let w = wt[id]
                let ws = w != nil ? " w=\(w!)pt" : ""
                print(String(format: "  ID=%d → rgb(%d,%d,%d)%@", id, Int(r*255), Int(g*255), Int(b*255), ws))
            }

            // Print each shape's colors
            for (i, shape) in result.shapes.enumerated() {
                let fill = shape.fillStyle.map { c -> String in
                    let (r,g,b) = c.color.rgbValues
                    return String(format: "rgb(%d,%d,%d)", Int(r*255), Int(g*255), Int(b*255))
                } ?? "none"
                let stroke = shape.strokeStyle.map { s -> String in
                    let (r,g,b) = s.color.rgbValues
                    return String(format: "rgb(%d,%d,%d) w=%.1fpt", Int(r*255), Int(g*255), Int(b*255), s.width)
                } ?? "none"
                print("  [\(i)] \(shape.name): fill=\(fill) stroke=\(stroke)")
            }
        } catch {
            print("Parse error: \(error)")
        }
    }

    static func generateSVG(shapes: [VectorShape], pageSize: CGSize, data: Data, gradients: [Int: FreeHand2Parser.GradientInfo]) -> String {
        // Helper to read fill ref from shape data (we need it for gradient lookup)
        func u16(_ d: Data, _ o: Int) -> Int { Int(d[d.startIndex+o])<<8|Int(d[d.startIndex+o+1]) }

        var defs: [String] = []
        var parts = [
            "<?xml version=\"1.0\"?>",
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(pageSize.width)\" height=\"\(pageSize.height)\" viewBox=\"0 0 \(pageSize.width) \(pageSize.height)\">",
            "<rect width=\"\(pageSize.width)\" height=\"\(pageSize.height)\" fill=\"white\"/>"
        ]

        // Find shape offsets to get fill refs for gradient lookup
        var shapeOffsets: [Int] = []
        var scanOff = 256
        while scanOff + 4 <= data.count {
            let sz = u16(data, scanOff); let rt = u16(data, scanOff+2)
            if (rt == 0x1519 && sz == 60) || (rt == 0x151A && sz == 56) || (rt == 0x151D && sz == 48) {
                shapeOffsets.append(scanOff)
            } else if rt == 0x151C && sz >= 44 && scanOff + sz <= data.count && scanOff + 29 < data.count {
                if sz == 44 + u16(data, scanOff+28) * 16 { shapeOffsets.append(scanOff) }
            }
            scanOff += 1
        }

        for (i, shape) in shapes.enumerated() {
            var fillStr: String
            // Check if this shape has a gradient fill
            let fillRef = (i < shapeOffsets.count) ? u16(data, shapeOffsets[i] + 18) : 0
            if let grad = gradients[fillRef] {
                let gid = "grad\(i)"
                let (r1,g1,b1) = grad.color1.rgbValues
                let (r2,g2,b2) = grad.color2.rgbValues
                let c1 = String(format: "rgb(%d,%d,%d)", Int(r1*255), Int(g1*255), Int(b1*255))
                let c2 = String(format: "rgb(%d,%d,%d)", Int(r2*255), Int(g2*255), Int(b2*255))
                defs.append("<linearGradient id=\"\(gid)\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"0\"><stop offset=\"0%\" stop-color=\"\(c1)\"/><stop offset=\"100%\" stop-color=\"\(c2)\"/></linearGradient>")
                fillStr = "url(#\(gid))"
            } else if let f = shape.fillStyle {
                let (r,g,b) = f.color.rgbValues
                fillStr = String(format: "rgb(%d,%d,%d)", Int(r*255), Int(g*255), Int(b*255))
            } else {
                fillStr = "none"
            }

            let strokeStr: String
            let strokeWidth: Double
            if let s = shape.strokeStyle {
                let (r,g,b) = s.color.rgbValues
                strokeStr = String(format: "rgb(%d,%d,%d)", Int(r*255), Int(g*255), Int(b*255))
                strokeWidth = s.width
            } else {
                strokeStr = "none"
                strokeWidth = 0
            }

            // Convert path elements to SVG path data
            var d = ""
            for el in shape.path.elements {
                switch el {
                case .move(let p): d += "M\(p.x) \(p.y) "
                case .line(let p): d += "L\(p.x) \(p.y) "
                case .curve(let p, let c1, let c2):
                    d += "C\(c1.x) \(c1.y) \(c2.x) \(c2.y) \(p.x) \(p.y) "
                case .quadCurve(let p, let c):
                    d += "Q\(c.x) \(c.y) \(p.x) \(p.y) "
                case .close: d += "Z "
                }
            }

            parts.append("<path d=\"\(d.trimmingCharacters(in: .whitespaces))\" fill=\"\(fillStr)\" stroke=\"\(strokeStr)\" stroke-width=\"\(strokeWidth)\"/>")
        }

        // Insert gradient defs before shapes
        if !defs.isEmpty {
            parts.insert("<defs>\(defs.joined())</defs>", at: 3)
        }
        parts.append("</svg>")
        return parts.joined(separator: "\n")
    }
}
