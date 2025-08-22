//
//  ToolItem.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// Stroke settings for toolbar icons
let IconStrokeWidth: CGFloat = 1.0
let IconStrokeExpand: CGFloat = IconStrokeWidth / 2.0

// MARK: - Tool Item for flexible toolbar display
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
