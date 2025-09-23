//
//  ShearAnchor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

enum ShearAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    
    var iconName: String {
        switch self {
        case .center: return "plus.circle"
        case .topLeft: return "arrow.up.left.circle"
        case .topRight: return "arrow.up.right.circle"
        case .bottomLeft: return "arrow.down.left.circle"
        case .bottomRight: return "arrow.down.right.circle"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}
