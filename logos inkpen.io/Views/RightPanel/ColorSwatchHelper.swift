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
                    .fill(Color.white)
                    .frame(width: width, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            } else {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: width, height: height)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            }
            
            // Diagonal red line for clear/none
            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(Color.red, lineWidth: 2)
            }
            .frame(width: width, height: height)
            .clipped()
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

// MARK: - Reusable Fill/Stroke Swatches Component

struct FillStrokeSwatches: View {
    let fillColor: VectorColor
    let strokeColor: VectorColor
    let fillOpacity: Double
    let strokeOpacity: Double
    let onFillTap: () -> Void
    let onStrokeTap: () -> Void
    let swatchSize: CGFloat
    let spacing: CGFloat
    
    init(
        fillColor: VectorColor,
        strokeColor: VectorColor,
        fillOpacity: Double = 1.0,
        strokeOpacity: Double = 1.0,
        onFillTap: @escaping () -> Void,
        onStrokeTap: @escaping () -> Void,
        swatchSize: CGFloat = 60,
        spacing: CGFloat = 30
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.fillOpacity = fillOpacity
        self.strokeOpacity = strokeOpacity
        self.onFillTap = onFillTap
        self.onStrokeTap = onStrokeTap
        self.swatchSize = swatchSize
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            // Fill Color
            VStack(spacing: 12) {
                Button(action: onFillTap) {
                    renderColorSwatchRightPanel(
                        fillColor,
                        width: swatchSize,
                        height: swatchSize,
                        cornerRadius: 4,
                        borderWidth: 1.5,
                        opacity: fillOpacity
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Stroke Color
            VStack(spacing: 12) {
                Button(action: onStrokeTap) {
                    renderColorSwatchRightPanel(
                        strokeColor,
                        width: swatchSize,
                        height: swatchSize,
                        cornerRadius: 4,
                        borderWidth: 1.5,
                        opacity: strokeOpacity
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Stroke")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Compact Fill/Stroke Swatches for Text

struct CompactFillStrokeSwatches: View {
    let fillColor: VectorColor
    let strokeColor: VectorColor?
    let fillOpacity: Double
    let strokeOpacity: Double
    let hasStroke: Bool
    let onFillTap: () -> Void
    let onStrokeTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Fill
            HStack(spacing: 8) {
                Text("Fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Button(action: onFillTap) {
                    renderColorSwatchRightPanel(
                        fillColor,
                        width: 30,
                        height: 20,
                        cornerRadius: 3,
                        borderWidth: 1,
                        opacity: fillOpacity
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Stroke (if enabled)
            if hasStroke, let strokeColor = strokeColor {
                HStack(spacing: 8) {
                    Text("Stroke")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Button(action: onStrokeTap) {
                        renderColorSwatchRightPanel(
                            strokeColor,
                            width: 30,
                            height: 20,
                            cornerRadius: 3,
                            borderWidth: 1,
                            opacity: strokeOpacity
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
} 