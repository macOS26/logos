//
//  CurrentColorsView.swift
//  logos inkpen.io
//
//  Current colors display view for StrokeFillPanel
//

import SwiftUI

struct CurrentColorsView: View {
    let strokeColor: VectorColor
    let fillColor: VectorColor
    let strokeOpacity: Double
    let fillOpacity: Double
    let onStrokeColorTap: () -> Void
    let onFillColorTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {  // Match ColorPanel spacing
            // Fill Color
            VStack(spacing: 4) {  // Compact spacing
                Button(action: onFillColorTap) {
                    renderColorSwatchRightPanel(fillColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1, opacity: fillOpacity)
                }
                .buttonStyle(BorderlessButtonStyle())

                Text("Fill")
                    .font(.caption2)  // Smaller font to match ColorPanel
                    .foregroundColor(Color.ui.secondaryText)
            }

            // Stroke Color
            VStack(spacing: 4) {  // Compact spacing
                Button(action: onStrokeColorTap) {
                    renderColorSwatchRightPanel(strokeColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1, opacity: strokeOpacity)
                }
                .buttonStyle(BorderlessButtonStyle())

                Text("Stroke")
                    .font(.caption2)  // Smaller font to match ColorPanel
                    .foregroundColor(Color.ui.secondaryText)
            }
        }
        .padding(12)  // Compact padding
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(8)
    }
}