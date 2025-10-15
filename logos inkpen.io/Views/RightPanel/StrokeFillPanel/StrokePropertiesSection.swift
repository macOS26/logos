import SwiftUI

struct StrokePropertiesSection: View {
    @ObservedObject var document: VectorDocument
    let strokeWidth: Double
    @Binding var strokePlacement: StrokePlacement
    let strokeOpacity: Double
    let strokeLineJoin: CGLineJoin
    let strokeLineCap: CGLineCap
    let strokeMiterLimit: Double
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokeOpacity: (Double) -> Void
    let onUpdateLineJoin: (CGLineJoin) -> Void
    let onUpdateLineCap: (CGLineCap) -> Void
    let onUpdateMiterLimit: (Double) -> Void
    let onStrokeWidthEditingChanged: (Bool) -> Void
    let onStrokeOpacityEditingChanged: (Bool) -> Void
    let onMiterLimitEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stroke")
                .font(.headline)
                .fontWeight(.medium)

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
                ), in: 0...72, onEditingChanged: onStrokeWidthEditingChanged)
                .controlSize(.regular)
            }

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
                ), in: 0...1, onEditingChanged: onStrokeOpacityEditingChanged)
                .controlSize(.regular)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Placement")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                Picker("Placement", selection: Binding(
                    get: { strokePlacement },
                    set: { newPlacement in
                        // Update state FIRST for immediate UI update
                        strokePlacement = newPlacement
                        document.defaultStrokePlacement = newPlacement

                        // Update selected shapes if any
                        for objectID in document.selectedObjectIDs {
                            if let unifiedObject = document.findObject(by: objectID) {
                                switch unifiedObject.objectType {
                                case .shape(let shape):
                                    if !shape.isTextObject {
                                        document.updateShapeStrokePlacementInUnified(id: shape.id, placement: newPlacement)
                                    }
                                }
                            }
                        }
                    }
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
                ), in: 1...20, onEditingChanged: onMiterLimitEditingChanged)
                .controlSize(.regular)
                .tint(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
