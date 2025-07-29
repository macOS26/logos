//
//  ColorSwatchHelper.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Checkerboard Pattern for Transparency

struct CheckerboardPattern: View {
    let size: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let tileSize = self.size
            let rows = Int(geometry.size.height / tileSize) + 1
            let cols = Int(geometry.size.width / tileSize) + 1
            
            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let isEven = (row + col) % 2 == 0
                                Rectangle()
            .fill(isEven ? Color.white : Color.gray.opacity(0.15))
                            .frame(width: tileSize, height: tileSize)
                            .position(
                                x: CGFloat(col) * tileSize + tileSize / 2,
                                y: CGFloat(row) * tileSize + tileSize / 2
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Color Rendering Helper (shared)

@ViewBuilder
func renderColorSwatchRightPanel(_ color: VectorColor, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 0, borderWidth: CGFloat = 0.5, opacity: Double = 1.0) -> some View {
    if case .clear = color {
        ZStack {
            // Checkerboard pattern to show transparency (use smaller size like VerticalToolbar)
            CheckerboardPattern(size: min(4, width / 4))
                .frame(width: width, height: height)
                .clipped()
            
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .border(Color.gray, width: borderWidth)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .border(Color.gray, width: borderWidth)
            }
            
            // Diagonal slash through the clear color (forward slash) - match VerticalToolbar style
                    Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: width, y: height))
        }
        .stroke(Color.red, lineWidth: 3)
        .frame(width: width, height: height)
        }
        .allowsHitTesting(true) // Ensure the clear color swatch doesn't block interactions
    } else {
        if cornerRadius > 0 {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color.color.opacity(opacity))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray, lineWidth: borderWidth)
                )
        } else {
            Rectangle()
                .fill(color.color.opacity(opacity))
                .frame(width: width, height: height)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray, lineWidth: borderWidth)
                )
        }
    }
} 