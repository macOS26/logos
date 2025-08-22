//
//  StarIcons.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// 3-Point Star (Mercedes-style curved)
struct ThreePointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.22 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 3

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 4-Point Star (diamond/cross shaped)
struct FourPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.28 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 4

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 5-Point Star (classic star)
struct FivePointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 5

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 6-Point Star (Star of David style)
struct SixPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 6

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 7-Point Star
struct SevenPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40 // matches DrawingCanvas+ShapeDrawing
            let points: Int = 7

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}

// 8-Point Star (compass rose style)
struct EightPointStarIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Draw using the exact star formula used by the canvas
            let center = CGPoint(x: 10, y: 10)
            let outerRadius: CGFloat = 8 + IconStrokeExpand
            let innerRadius: CGFloat = outerRadius * 0.40
            let points: Int = 8

            let angleStep = .pi / Double(points)
            for i in 0..<(points * 2) {
                let angle = Double(i) * angleStep - .pi / 2
                let r = (i % 2 == 0) ? outerRadius : innerRadius
                let x = center.x + cos(angle) * r
                let y = center.y + sin(angle) * r
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
