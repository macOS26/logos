//
//  FillPropertiesSection.swift
//  logos inkpen.io
//
//  Fill properties section for StrokeFillPanel
//

import SwiftUI

struct FillPropertiesSection: View {
    let fillOpacity: Double
    let onApplyFill: () -> Void
    let onUpdateFillOpacity: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill Properties")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(fillOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(value: Binding(
                    get: { fillOpacity },
                    set: { onUpdateFillOpacity($0) }
                ), in: 0...1)
                .controlSize(.regular)
            }

            Button("Apply Fill") {
                onApplyFill()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}