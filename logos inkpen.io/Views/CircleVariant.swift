//
//  CircleVariant.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// Circle Variants
enum CircleVariant: String, CaseIterable {
    case ellipse = "Ellipse"
    case oval = "Oval"
    case circle = "Circle"
    case egg = "Egg"
    case cone = "Cone"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .ellipse:
            EllipseIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .oval:
            OvalIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .circle:
            CircleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .egg:
            EggIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .cone:
            ConeIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}
