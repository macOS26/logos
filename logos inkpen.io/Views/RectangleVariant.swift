//
//  RectangleVariant.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// Rectangle Variants
enum RectangleVariant: String, CaseIterable {
    case rectangle = "Rectangle"
    case square = "Square"
    case roundedRectangle = "Rounded Rectangle"
    case pill = "Pill"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .rectangle:
            RectangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .square:
            SquareIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .roundedRectangle:
            RoundedRectangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .pill:
            PillIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}
