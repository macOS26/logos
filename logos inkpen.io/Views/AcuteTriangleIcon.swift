//
//  AcuteTriangleIcon.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

struct AcuteTriangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Acute triangle (all angles less than 90 degrees)
            // Tall, narrow triangle with sharp angles
            let baseWidth: CGFloat = 8
            let height: CGFloat = 12
            
            let center = CGPoint(x: 10, y: 10)
            let topPoint = CGPoint(x: center.x, y: center.y - height * 0.5 - IconStrokeExpand)
            let bottomLeft = CGPoint(x: center.x - baseWidth * 0.5 - IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            let bottomRight = CGPoint(x: center.x + baseWidth * 0.5 + IconStrokeExpand, y: center.y + height * 0.5 + IconStrokeExpand)
            
            path.move(to: topPoint)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
