//
//  GradientHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI
import AppKit


// Note: formatNumberForDisplay function is imported from StrokeFillPanel.swift

/// Creates a number input binding that shows exactly what user types
func createNaturalNumberBinding(
    getValue: @escaping () -> Double,
    setValue: @escaping (Double) -> Void
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
