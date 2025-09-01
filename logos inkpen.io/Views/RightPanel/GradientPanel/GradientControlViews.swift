//
//  GradientControlViews.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI

// MARK: - Gradient Control Views

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
                    // Create default gradient if none exists
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
                            // DEBOUNCED: Only do expensive sync when drag ends
                            // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                            document.syncUnifiedObjectsAfterPropertyChange()
                            document.saveToUndoStack() 
                        }
                    })
                    .controlSize(.small)
                    
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
                        Text("X: \(currentGradient != nil ? formatNumberForDisplay(getOriginX(currentGradient!)) : "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginX(currentGradient!) : 0.0 },
                                set: updateOriginX
                            ), in: 0.0...1.0, onEditingChanged: { editing in
                                if !editing { 
                                    // DEBOUNCED: Only do expensive sync when drag ends
                                    // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                                    document.syncUnifiedObjectsAfterPropertyChange()
                                    document.saveToUndoStack() 
                                }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getOriginX(currentGradient!) : 0.0 },
                                setValue: updateOriginX
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Y: \(currentGradient != nil ? formatNumberForDisplay(getOriginY(currentGradient!)) : "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginY(currentGradient!) : 0.0 },
                                set: updateOriginY
                            ), in: 0.0...1.0, onEditingChanged: { editing in
                                if !editing { 
                                    // DEBOUNCED: Only do expensive sync when drag ends
                                    // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                                    document.syncUnifiedObjectsAfterPropertyChange()
                                    document.saveToUndoStack() 
                                }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getOriginY(currentGradient!) : 0.0 },
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
                // Uniform Scale Control
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale: \(currentGradient != nil ? Int(getScale(currentGradient!) * 100) : 100)%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getScale(currentGradient!) : 1.0 },
                            set: { newScale in
                                updateScale(newScale)
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing { 
                                // DEBOUNCED: Only do expensive sync when drag ends
                                // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                                document.syncUnifiedObjectsAfterPropertyChange()
                                document.saveToUndoStack() 
                            }
                        })
                        .controlSize(.small)
                        
                        TextField("", text: createNaturalNumberBinding(
                            getValue: { currentGradient != nil ? getScale(currentGradient!) : 1.0 },
                            setValue: updateScale
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.system(size: 11))
                    }
                }
                
                // Aspect Ratio Control (X=1, Y=0 to 1) - ONLY for Radial Gradients
                if case .radial = currentGradient {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aspect Ratio: \(currentGradient != nil ? formatNumberForDisplay(getAspectRatio(currentGradient!)) : "1")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getAspectRatio(currentGradient!) : 1.0 },
                                set: { newAspectRatio in
                                    updateAspectRatio(newAspectRatio)
                                }
                            ), in: 0.01...2.0, onEditingChanged: { editing in
                                if !editing { 
                                    // DEBOUNCED: Only do expensive sync when drag ends
                                    // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                                    document.syncUnifiedObjectsAfterPropertyChange()
                                    document.saveToUndoStack() 
                                }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getAspectRatio(currentGradient!) : 1.0 },
                                setValue: updateAspectRatio
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    // Radius Control - ONLY for Radial Gradients
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Radius: \(currentGradient != nil ? formatNumberForDisplay(getRadius(currentGradient!)) : "0.5")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getRadius(currentGradient!) : 0.5 },
                                set: { newRadius in
                                    updateRadius(newRadius)
                                }
                            ), in: 0.1...2.0, onEditingChanged: { editing in
                                if !editing { 
                                    // DEBOUNCED: Only do expensive sync when drag ends
                                    // (gradient already applied during drag via applyGradientToSelectedShapesOptimized)
                                    document.syncUnifiedObjectsAfterPropertyChange()
                                    document.saveToUndoStack() 
                                }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getRadius(currentGradient!) : 0.5 },
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
        HStack {
            Spacer()
            Button("Add Swatch", action: onAddSwatch)
                .buttonStyle(.bordered)
                .disabled(currentGradient == nil)
            Button("Apply Gradient", action: onApply)
                .buttonStyle(.borderedProminent)
                .disabled(currentGradient == nil)
        }
    }
}