
import SwiftUI


struct GradientTypePickerView: View {
    @Binding var gradientType: GradientFillSection.GradientType
    @Binding var currentGradient: VectorGradient?
    @Binding var gradientId: UUID
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let createGradientPreservingProperties: (GradientFillSection.GradientType, [GradientStop], VectorGradient) -> VectorGradient
    let createDefaultGradient: (GradientFillSection.GradientType) -> VectorGradient
    let onGradientChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.caption)
                .foregroundColor(Color.ui.secondaryText)

            Picker("Gradient Type", selection: $gradientType) {
                ForEach(GradientFillSection.GradientType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: gradientType) { _, newValue in
                if let currentGradient = currentGradient {
                    let preservedStops = getGradientStops(currentGradient)
                    self.currentGradient = createGradientPreservingProperties(newValue, preservedStops, currentGradient)
                } else {
                    currentGradient = createDefaultGradient(newValue)
                }
                gradientId = UUID()
                onGradientChange()
            }
        }
    }
}

struct GradientAngleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let onAngleChange: (Double) -> Void

    var body: some View {
        if let gradient = currentGradient {
            let angle: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.angle
                case .radial(let radial):
                    return radial.angle
                }
            }()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Angle")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(angle, maxDecimals: 1))°")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { angle },
                        set: onAngleChange
                    ), in: -180...180, onEditingChanged: { editing in
                        if !editing {
                            document.updateUnifiedObjectsOptimized()
                            document.saveToUndoStack()
                        }
                    })
                    .controlSize(.regular)

                    TextField("", text: createNaturalNumberBinding(
                        getValue: { angle },
                        setValue: onAngleChange
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                }
            }
        }
    }
}

struct GradientOriginControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let updateOriginX: (Double) -> Void
    let updateOriginY: (Double) -> Void

    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Origin Point")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("0 to 1")
                        .font(.caption2)
                        .foregroundColor(Color.ui.primaryBlue)
                        .padding(.horizontal, 4)
                        .background(Color.ui.lightBlueBackground)
                        .cornerRadius(3)
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("X: \(currentGradient.map { formatNumberForDisplay(getOriginX($0)) } ?? "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)

                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getOriginX($0) } ?? 0.0 },
                                set: updateOriginX
                            ), in: 0.0...1.0, onEditingChanged: { editing in
                                if !editing {
                                    document.updateUnifiedObjectsOptimized()
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.regular)

                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getOriginX($0) } ?? 0.0 },
                                setValue: updateOriginX
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Y: \(currentGradient.map { formatNumberForDisplay(getOriginY($0)) } ?? "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)

                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getOriginY($0) } ?? 0.0 },
                                set: updateOriginY
                            ), in: 0.0...1.0, onEditingChanged: { editing in
                                if !editing {
                                    document.updateUnifiedObjectsOptimized()
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.regular)

                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getOriginY($0) } ?? 0.0 },
                                setValue: updateOriginY
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }
}

struct GradientScaleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getScale: (VectorGradient) -> Double
    let updateScale: (Double) -> Void
    let getAspectRatio: (VectorGradient) -> Double
    let updateAspectRatio: (Double) -> Void
    let getRadius: (VectorGradient) -> Double
    let updateRadius: (Double) -> Void

    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale: \(currentGradient.map { Int(getScale($0) * 100) } ?? 100)%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)

                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { currentGradient.map { getScale($0) } ?? 1.0 },
                            set: { newScale in
                                updateScale(newScale)
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing {
                                document.updateUnifiedObjectsOptimized()
                                document.saveToUndoStack()
                            }
                        })
                        .controlSize(.regular)

                        TextField("", text: createNaturalNumberBinding(
                            getValue: { currentGradient.map { getScale($0) } ?? 1.0 },
                            setValue: updateScale
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.system(size: 11))
                    }
                }

                if case .radial = currentGradient {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aspect Ratio: \(currentGradient.map { formatNumberForDisplay(getAspectRatio($0)) } ?? "1")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)

                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getAspectRatio($0) } ?? 1.0 },
                                set: { newAspectRatio in
                                    updateAspectRatio(newAspectRatio)
                                }
                            ), in: 0.01...2.0, onEditingChanged: { editing in
                                if !editing {
                                    document.updateUnifiedObjectsOptimized()
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.regular)

                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getAspectRatio($0) } ?? 1.0 },
                                setValue: updateAspectRatio
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Radius: \(currentGradient.map { formatNumberForDisplay(getRadius($0)) } ?? "0.5")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)

                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getRadius($0) } ?? 0.5 },
                                set: { newRadius in
                                    updateRadius(newRadius)
                                }
                            ), in: 0.1...2.0, onEditingChanged: { editing in
                                if !editing {
                                    document.updateUnifiedObjectsOptimized()
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.regular)

                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getRadius($0) } ?? 0.5 },
                                setValue: updateRadius
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }
}

struct GradientApplyButtonView: View {
    let currentGradient: VectorGradient?
    let onApply: () -> Void
    let onAddSwatch: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                onAddSwatch()
            } label: {
                Text("Add Swatch")
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .onTapGesture {
                onAddSwatch()
            }

            Button {
                onApply()
            } label: {
                Text("Apply Gradient")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .frame(minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
            .onTapGesture {
                onApply()
            }
        }
    }
}