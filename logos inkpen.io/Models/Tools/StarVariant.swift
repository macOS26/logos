//
//  StarVariant.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Star Variants
enum StarVariant: String, CaseIterable {
    case threePoint = "3-Point Star"
    case fourPoint = "4-Point Star" 
    case fivePoint = "5-Point Star"
    case sixPoint = "6-Point Star"
    case sevenPoint = "7-Point Star"
    
    @ViewBuilder
    func iconView(isSelected: Bool, color: Color = .primary) -> some View {
        switch self {
        case .threePoint:
            ThreePointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .fourPoint:
            FourPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .fivePoint:
            FivePointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .sixPoint:
            SixPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        case .sevenPoint:
            SevenPointStarIcon(isSelected: isSelected)
                .foregroundColor(color)
        }
    }
}
