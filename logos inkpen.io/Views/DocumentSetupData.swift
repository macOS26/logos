//
//  DocumentSetupData.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// MARK: - Document Setup Data Model
struct DocumentSetupData {
    var width: Double = 11.0
    var height: Double = 8.5
    var unit: MeasurementUnit = .inches
    var filename: String = "Untitled"
    var colorMode: ColorMode = .rgb
    var resolution: Double = 72.0
    var showRulers: Bool = true
    var showGrid: Bool = false
    var snapToGrid: Bool = false
    var backgroundColor: VectorColor = .white
    var freehandSmoothingTolerance: Double = 2.0
    var brushThickness: Double = 10.0
    var brushPressureSensitivity: Double = 0.5
    var brushTaper: Double = 0.3
    
    // Advanced Smoothing Settings
    var advancedSmoothingEnabled: Bool = true
    var chaikinSmoothingIterations: Int = 1
    var realTimeSmoothingEnabled: Bool = true
    var realTimeSmoothingStrength: Double = 0.3
    var adaptiveTensionEnabled: Bool = true
    var preserveSharpCorners: Bool = true
    
    var documentSettings: DocumentSettings {
        DocumentSettings(
            width: width,
            height: height,
            unit: unit,
            colorMode: colorMode,
            resolution: resolution,
            showRulers: showRulers,
            showGrid: showGrid,
            snapToGrid: snapToGrid,
            gridSpacing: 0.125,
            backgroundColor: backgroundColor,
            freehandSmoothingTolerance: freehandSmoothingTolerance,
            brushThickness: brushThickness,
            brushPressureSensitivity: brushPressureSensitivity,
            brushTaper: brushTaper,
            advancedSmoothingEnabled: advancedSmoothingEnabled,
            chaikinSmoothingIterations: chaikinSmoothingIterations,
            realTimeSmoothingEnabled: realTimeSmoothingEnabled,
            realTimeSmoothingStrength: realTimeSmoothingStrength,
            adaptiveTensionEnabled: adaptiveTensionEnabled,
            preserveSharpCorners: preserveSharpCorners
        )
    }
}
