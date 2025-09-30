//
//  PressureCurveEditor.swift
//  logos inkpen.io
//
//  Interactive pressure curve editor for mapping input pressure to output thickness
//

import SwiftUI

struct PressureCurveEditor: View {
    @Binding var pressureCurve: [CGPoint]
    @State private var selectedControlPoint: Int?
    @State private var isDragging = false

    let size: CGFloat

    init(pressureCurve: Binding<[CGPoint]>, size: CGFloat = 280) {
        self._pressureCurve = pressureCurve
        self.size = size
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Pressure Curve")
                .font(.headline)
                .foregroundColor(.primary)

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
                    guard pressureCurve.count >= 2 else { return }

                    let firstPoint = pressureCurve[0]
                    path.move(to: CGPoint(x: firstPoint.x * size, y: size - firstPoint.y * size))

                    for i in 1..<pressureCurve.count {
                        let point = pressureCurve[i]
                        path.addLine(to: CGPoint(x: point.x * size, y: size - point.y * size))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // Control points - FIXED: Use overlay with proper gesture handling
                ForEach(0..<pressureCurve.count, id: \.self) { index in
                    let point = pressureCurve[index]
                    let isSelected = selectedControlPoint == index

                    Circle()
                        .fill(isSelected ? Color.red : Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: point.x * size, y: size - point.y * size)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Select this point on drag start
                                    if !isDragging {
                                        selectedControlPoint = index
                                        isDragging = true
                                    }

                                    // Update position
                                    let newX = max(0, min(1, value.location.x / size))
                                    let newY = max(0, min(1, (size - value.location.y) / size))
                                    pressureCurve[index] = CGPoint(x: newX, y: newY)

                                    // Sort points by x value to maintain order
                                    pressureCurve.sort { $0.x < $1.x }

                                    // Update selected index after sorting
                                    selectedControlPoint = pressureCurve.firstIndex {
                                        abs($0.x - newX) < 0.01 && abs($0.y - newY) < 0.01
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                        .onTapGesture {
                            selectedControlPoint = index
                        }
                }
            }
            .frame(width: size, height: size)

            // Curve info
            HStack {
                Text("Input: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Output: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: size)

            // Control point info
            if let selected = selectedControlPoint, selected < pressureCurve.count {
                let point = pressureCurve[selected]
                HStack {
                    Text("Point \(selected + 1):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "In: %.2f, Out: %.2f", point.x, point.y))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .monospaced()
                }
                .frame(width: size)
            }
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
    return lowerPoint.y + t * (upperPoint.y - lowerPoint.y)
}

#Preview {
    PressureCurveEditor(
        pressureCurve: .constant([
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]),
        size: 280
    )
    .padding()
}