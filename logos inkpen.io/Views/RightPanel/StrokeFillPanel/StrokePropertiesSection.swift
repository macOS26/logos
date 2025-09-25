//
//  StrokePropertiesSection.swift
//  logos inkpen.io
//
//  Stroke properties section for StrokeFillPanel
//

import SwiftUI

struct StrokePropertiesSection: View {
    let strokeWidth: Double
    let strokePlacement: StrokePlacement
    let strokeOpacity: Double // PROFESSIONAL STROKE TRANSPARENCY
    let strokeLineJoin: CGLineJoin // PROFESSIONAL JOIN TYPES
    let strokeLineCap: CGLineCap // PROFESSIONAL ENDCAPS
    let strokeMiterLimit: Double // PROFESSIONAL MITER LIMIT
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeOpacity: (Double) -> Void // PROFESSIONAL STROKE TRANSPARENCY
    let onUpdateLineJoin: (CGLineJoin) -> Void // PROFESSIONAL JOIN TYPES
    let onUpdateLineCap: (CGLineCap) -> Void // PROFESSIONAL ENDCAPS
    let onUpdateMiterLimit: (Double) -> Void // PROFESSIONAL MITER LIMIT

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stroke Properties")
                .font(.headline)
                .fontWeight(.medium)

            // Stroke Width
            VStack(spacing: 8) {
                HStack {
                    Text("Width")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(String(format: "%.1f", strokeWidth)) pt")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(value: Binding(
                    get: { strokeWidth },
                    set: { onUpdateStrokeWidth($0) }
                ), in: 0...20)
                .controlSize(.regular)
            }

            // PROFESSIONAL STROKE TRANSPARENCY (Professional Standard)
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(strokeOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(value: Binding(
                    get: { strokeOpacity },
                    set: { onUpdateStrokeOpacity($0) }
                ), in: 0...1)
                .controlSize(.regular)
            }

            // Stroke Placement
            VStack(alignment: .leading, spacing: 4) {
                Text("Placement")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                Picker("Placement", selection: Binding(
                    get: { strokePlacement },
                    set: { onUpdateStrokePlacement($0) }
                )) {
                    ForEach(StrokePlacement.allCases, id: \.self) { placement in
                        HStack {
                            Image(systemName: placement.iconName)
                            Text(placement.rawValue)
                        }
                        .tag(placement)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }

            // PROFESSIONAL JOIN TYPE CONTROL (Professional Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("Joins")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                HStack(spacing: 6) {
                    ForEach([CGLineJoin.round, .miter, .bevel], id: \.self) { joinType in
                        Button {
                            onUpdateLineJoin(joinType)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: joinType.iconName)
                                    .font(.system(size: 12))

                                Text(joinType.displayName)
                                    .font(.caption2)
                            }
                            .foregroundColor(strokeLineJoin == joinType ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(strokeLineJoin == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(strokeLineJoin == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(joinType.description)
                    }
                }
            }

            // PROFESSIONAL ENDCAP CONTROL (Professional Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("End Caps")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                HStack(spacing: 6) {
                    ForEach([CGLineCap.butt, .round, .square], id: \.self) { capType in
                        Button {
                            onUpdateLineCap(capType)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: capType.iconName)
                                    .font(.system(size: 12))

                                Text(capType.displayName)
                                    .font(.caption2)
                            }
                            .foregroundColor(strokeLineCap == capType ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(strokeLineCap == capType ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(strokeLineCap == capType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(capType.description)
                    }
                }
            }

            // Miter Limit - ALWAYS VISIBLE, NO RESTRICTIONS
            VStack(spacing: 8) {
                HStack {
                    Text("Miter Limit")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(String(format: "%.1f", strokeMiterLimit))")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(value: Binding(
                    get: { strokeMiterLimit },
                    set: { onUpdateMiterLimit($0) }
                ), in: 1...20)
                .controlSize(.regular)
                .tint(.blue)
            }
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
