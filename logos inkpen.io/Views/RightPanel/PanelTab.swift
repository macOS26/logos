//
//  PanelTab.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

enum PanelTab: String, CaseIterable {
    case layers = "Layers"
    case properties = "Paint"
    case gradient = "Gradient"
    case color = "Color"
    case pathOps = "Path"
    case font = "Font"
    
    var iconName: String {
        switch self {
        case .layers: return "square.stack"
        case .properties: return "paintbrush"
        case .gradient: return "circle.lefthalf.striped.horizontal"
        case .color: return "paintpalette"
        case .pathOps: return "square.grid.2x2"
        case .font: return "textformat"
        }
    }
} 