//
//  QuickSize.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Quick Size Model
struct QuickSize: Hashable {
    let name: String
    let baseWidth: Double
    let baseHeight: Double
    let baseUnit: MeasurementUnit
}
