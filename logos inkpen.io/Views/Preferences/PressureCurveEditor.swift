//
//  PressureCurveEditor.swift
//  logos inkpen.io
//
//  Interactive pressure curve editor for mapping input pressure to output thickness
//

import SwiftUI

struct PressureCurveEditor: View {
    @Binding var curve: [CGPoint]
    @State private var selectedControlPoint: Int?
    let size: CGFloat

    init(curve: Binding<[CGPoint]>, size: CGFloat = 280) {
        self._curve = curve
        self.size = size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pressure Curve")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(String(format: "Input: %.2f-%.2f → Output: %.2f-%.2f",
                                curve.map(\.x).min() ?? 0.0,
                                curve.map(\.x).max() ?? 1.0,
                                curve.map(\.y).min() ?? 0.0,
                                curve.map(\.y).max() ?? 1.0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Control Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(0..<curve.count, id: \.self) { index in
                        Text(String(format: "(%.2f, %.2f)", curve[index].x, curve[index].y))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(selectedControlPoint == index ? .red : .secondary)
                    }
                }
            }

            ZStack {
                // Background grid
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .border(Color.gray.opacity(0.3), width: 1)

                // Grid lines
                Path { path in
                    // Vertical lines
                    let gridCount = 10
                    for i in 0...gridCount {
                        let x = CGFloat(i) * (size / CGFloat(gridCount))
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size))
                    }
                    // Horizontal lines
                    for i in 0...gridCount {
                        let y = CGFloat(i) * (size / CGFloat(gridCount))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)

                // Curve path
                Path { path in
                    guard curve.count >= 2 else { return }

                    let firstPoint = curve[0]
                    path.move(to: CGPoint(x: firstPoint.x * size, y: size - firstPoint.y * size))

                    for i in 1..<curve.count {
                        let point = curve[i]
                        path.addLine(to: CGPoint(x: point.x * size, y: size - point.y * size))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // Control points
                ForEach(curve.indices, id: \.self) { index in
                    let point = curve[index]
                    let isSelected = selectedControlPoint == index

                    Circle()
                        .fill(isSelected ? Color.red : Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: point.x * size, y: size - point.y * size)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Update position
                                    let newX = max(0, min(1, value.location.x / size))
                                    let newY = max(0, min(1, (size - value.location.y) / size))

                                    // Create NEW array to trigger Binding update
                                    var newCurve = curve
                                    newCurve[index] = CGPoint(x: newX, y: newY)
                                    curve = newCurve

                                    selectedControlPoint = index
                                }
                                .onEnded { _ in
                                    selectedControlPoint = nil
                                }
                        )
                        .onTapGesture {
                            selectedControlPoint = index
                        }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// Helper function to get thickness from pressure curve
func getThicknessFromPressureCurve(pressure: Double, curve: [CGPoint]) -> Double {
    guard curve.count >= 2 else { return pressure }

    // Clamp pressure to valid range
    let clampedPressure = max(0.0, min(1.0, pressure))

    // Find the two control points that bracket the input pressure
    var lowerIndex = 0
    for i in 0..<curve.count {
        if curve[i].x <= clampedPressure {
            lowerIndex = i
        } else {
            break
        }
    }

    let upperIndex = min(lowerIndex + 1, curve.count - 1)
    let lowerPoint = curve[lowerIndex]
    let upperPoint = curve[upperIndex]

    // Linear interpolation between the two points
    if upperPoint.x == lowerPoint.x {
        return lowerPoint.y
    }

    let t = (clampedPressure - lowerPoint.x) / (upperPoint.x - lowerPoint.x)
    let curveOutput = lowerPoint.y + t * (upperPoint.y - lowerPoint.y)

    // Convert curve output to thickness multiplier
    // Linear curve (input=output) → multiplier = 1.0 (no thickness change)
    // Soft curve (output>input) → multiplier > 1.0 (thicker)
    // Hard curve (output<input) → multiplier < 1.0 (thinner)
    if clampedPressure == 0 {
        return curveOutput == 0 ? 1.0 : 0.0
    }
    return curveOutput / clampedPressure
}

#Preview {
    @Previewable @State var previewCurve: [CGPoint] = [
        CGPoint(x: 0.0, y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0, y: 1.0)
    ]

    return PressureCurveEditor(curve: $previewCurve, size: 280)
        .padding()
}