
import SwiftUI

let IconStrokeWidth: CGFloat = 1.0
let IconStrokeExpand: CGFloat = IconStrokeWidth / 2.0

struct ToolItem {
    let tool: DrawingTool
    let starVariant: StarVariant?

    var toolIdentifier: String {
        if let variant = starVariant {
            return "star_\(variant.rawValue)"
        } else {
            return tool.rawValue
        }
    }
}
