//
//  ColorSwatchHelper.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Color Rendering Helper (shared)

@ViewBuilder
func renderColorSwatchRightPanel(_ color: VectorColor, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 0, borderWidth: CGFloat = 0.5, opacity: Double = 1.0) -> some View {
    if case .clear = color {
        ZStack {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            }
            
            // Diagonal slash through the clear color (forward slash)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: width - 1, y: height - 1))
            }
            .stroke(Color.red, lineWidth: max(1, width / 15))
        }
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