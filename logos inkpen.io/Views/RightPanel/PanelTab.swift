//
//  PanelTab.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

enum PanelTab: String, CaseIterable {
    case layers = "Layers"
    case properties = "Stroke/Fill"
    case color = "Color"
    case pathOps = "Path Ops"
    
    var iconName: String {
        switch self {
        case .layers: return "square.stack"
        case .properties: return "paintbrush"
        case .color: return "paintpalette"
        case .pathOps: return "square.grid.2x2"
        }
    }
} 