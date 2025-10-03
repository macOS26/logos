//
//  PreferencesView.swift
//  logos inkpen.io
//
//  Application preferences window
//

import SwiftUI

// Helper function to create default curve data
func defaultPressureCurveData() -> Data {
    let defaultCurve = [
        CGPoint(x: 0.0, y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0, y: 1.0)
    ]
    return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
}
