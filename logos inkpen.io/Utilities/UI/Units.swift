//
//  Units.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Units
enum MeasurementUnit: String, CaseIterable, Codable {
    case inches = "Inches"
    case centimeters = "cm"
    case millimeters = "mm"
    case points = "Points"
    case pixels = "Pixels"
    case picas = "Picas"
    
    var abbreviation: String {
        switch self {
        case .inches: return "in"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        case .points: return "pt"
        case .pixels: return "px"
        case .picas: return "pc"
        }
    }
    
    var pointsPerUnit: Double {
        switch self {
        case .inches: return 72.0
        case .centimeters: return 28.346
        case .millimeters: return 2.835
        case .points: return 1.0
        case .pixels: return 1.0 // Assuming 72 DPI
        case .picas: return 12.0
        }
    }
}


// MARK: - Zoom Request System
enum ZoomMode: Equatable {
    case zoomIn
    case zoomOut
    case fitToPage
    case actualSize
    case custom(CGPoint) // Custom zoom with focal point
}

struct ZoomRequest: Equatable {
    let targetZoom: CGFloat
    let mode: ZoomMode

    init(targetZoom: CGFloat, mode: ZoomMode) {
        self.targetZoom = targetZoom
        self.mode = mode
    }
}
