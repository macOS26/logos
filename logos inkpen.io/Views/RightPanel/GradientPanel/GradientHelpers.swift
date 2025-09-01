//
//  GradientHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI
import AppKit

// MARK: - Helper Functions
// Note: formatNumberForDisplay function is imported from StrokeFillPanel.swift

struct NumberTextField: View {
    let value: Double
    let onValueChange: (Double) -> Void
    let range: ClosedRange<Double>
    
    var body: some View {
        TextField("", text: createNaturalNumberBinding(
            getValue: { value },
            setValue: { newValue in
                let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                onValueChange(clampedValue)
            }
        ))
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .frame(width: 60)
        .font(.system(size: 11))
    }
}

/// Creates a number input binding that shows exactly what user types
func createNaturalNumberBinding(
    getValue: @escaping () -> Double,
    setValue: @escaping (Double) -> Void,
    formatter: @escaping (Double) -> String = { formatNumberForDisplay($0) }
) -> Binding<String> {
    return Binding<String>(
        get: {
            let value = getValue()
            return String(value)
        },
        set: { newStringValue in
            // Show exactly what user typed - no filtering!
            // Only clamp the actual value if it's out of bounds
            if let doubleValue = Double(newStringValue) {
                setValue(doubleValue)
            }
        }
    )
}