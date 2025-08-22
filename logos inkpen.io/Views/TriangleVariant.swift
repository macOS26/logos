//
//  TriangleVariant.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// Triangle Variants
enum TriangleVariant: String, CaseIterable {
    case equilateral = "Equilateral Triangle"
    case right = "Right Triangle"
    case acute = "Acute Triangle"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .equilateral:
            EquilateralTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .right:
            RightTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .acute:
            AcuteTriangleIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}
