//
//  DWFExportOptions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//
// MARK: - DWF Export Data Structures

import Foundation
import SwiftUI
import CoreGraphics

/// Professional DWF export options
struct DWFExportOptions {
    let scale: DWFScale
    let targetUnits: VectorUnit
    let flipYAxis: Bool
    let customOrigin: CGPoint?
    let author: String?
    let title: String?
    let description: String?
    
    init(scale: DWFScale = .fullSize,
         targetUnits: VectorUnit = .points,
         flipYAxis: Bool = true,
         customOrigin: CGPoint? = nil,
         author: String? = nil,
         title: String? = nil,
         description: String? = nil) {
        self.scale = scale
        self.targetUnits = targetUnits
        self.flipYAxis = flipYAxis
        self.customOrigin = customOrigin
        self.author = author
        self.title = title
        self.description = description
    }
}

/// Professional DWF scales (AutoCAD standards)
enum DWFScale {
    // Architectural scales (AutoCAD standard)
    case architectural_1_16    // 1/16" = 1'-0"
    case architectural_1_8     // 1/8" = 1'-0"
    case architectural_1_4     // 1/4" = 1'-0"
    case architectural_1_2     // 1/2" = 1'-0"
    case architectural_1_1     // 1" = 1'-0"
    
    // Engineering scales (AutoCAD standard)
    case engineering_1_10      // 1" = 10'-0"
    case engineering_1_20      // 1" = 20'-0"
    case engineering_1_50      // 1" = 50'-0"
    case engineering_1_100     // 1" = 100'-0"
    
    // Metric scales (International standard)
    case metric_1_100          // 1:100
    case metric_1_200          // 1:200
    case metric_1_500          // 1:500
    case metric_1_1000         // 1:1000
    
    case fullSize              // 1:1
    case custom(CGFloat)       // Custom scale factor
    
    var description: String {
        switch self {
        case .architectural_1_16: return "1/16\"=1'-0\""
        case .architectural_1_8:  return "1/8\"=1'-0\""
        case .architectural_1_4:  return "1/4\"=1'-0\""
        case .architectural_1_2:  return "1/2\"=1'-0\""
        case .architectural_1_1:  return "1\"=1'-0\""
        case .engineering_1_10:   return "1\"=10'-0\""
        case .engineering_1_20:   return "1\"=20'-0\""
        case .engineering_1_50:   return "1\"=50'-0\""
        case .engineering_1_100:  return "1\"=100'-0\""
        case .metric_1_100:       return "1:100"
        case .metric_1_200:       return "1:200"
        case .metric_1_500:       return "1:500"
        case .metric_1_1000:      return "1:1000"
        case .fullSize:           return "1:1"
        case .custom(let factor): return "1:\(Int(1.0/factor))"
        }
    }
}

/// DWF opcode structure (Autodesk specification)
enum DWFOpcode {
    case drawingInfo(bounds: CGRect, units: VectorUnit, scale: DWFScale, author: String, title: String, description: String?)
    case layerDefinition(name: String, index: Int)
    case moveTo(CGPoint)
    case lineTo(CGPoint)
    case quadCurve(controlPoint: CGPoint, endPoint: CGPoint)
    case cubicCurve(control1: CGPoint, control2: CGPoint, endPoint: CGPoint)
    case closePath
    case setStroke(width: CGFloat, color: NSColor)
    case setFill(color: NSColor)
}

/// DWF export content structure
struct DWFExportContent {
    let opcodes: [DWFOpcode]
    let shapeCount: Int
    let layerCount: Int
    let bounds: CGRect
    let scale: DWFScale
    let units: VectorUnit
}

// MARK: - DWG Export Data Structures (AutoCAD Standards)

/// Professional DWG export options
struct DWGExportOptions {
    let scale: DWGScale
    let targetUnits: VectorUnit
    let flipYAxis: Bool
    let customOrigin: CGPoint?
    let author: String?
    let title: String?
    let description: String?
    let dwgVersion: DWGVersion
    let includeReferenceRectangle: Bool
    let defaultLineType: DWGLineType
    
    init(scale: DWGScale = .fullSize,
         targetUnits: VectorUnit = .points,
         flipYAxis: Bool = true,
         customOrigin: CGPoint? = nil,
         author: String? = nil,
         title: String? = nil,
         description: String? = nil,
         dwgVersion: DWGVersion = .r2018,
         includeReferenceRectangle: Bool = true,
         defaultLineType: DWGLineType = .continuous) {
        self.scale = scale
        self.targetUnits = targetUnits
        self.flipYAxis = flipYAxis
        self.customOrigin = customOrigin
        self.author = author
        self.title = title
        self.description = description
        self.dwgVersion = dwgVersion
        self.includeReferenceRectangle = includeReferenceRectangle
        self.defaultLineType = defaultLineType
    }
}

/// Professional DWG scales
enum DWGScale {
    // Architectural scales (AutoCAD standard)
    case architectural_1_16    // 1/16" = 1'-0"
    case architectural_1_8     // 1/8" = 1'-0"
    case architectural_1_4     // 1/4" = 1'-0"
    case architectural_1_2     // 1/2" = 1'-0"
    case architectural_1_1     // 1" = 1'-0"
    
    // Engineering scales (AutoCAD standard)
    case engineering_1_10      // 1" = 10'-0"
    case engineering_1_20      // 1" = 20'-0"
    case engineering_1_50      // 1" = 50'-0"
    case engineering_1_100     // 1" = 100'-0"
    
    // Metric scales (International standard)
    case metric_1_100          // 1:100
    case metric_1_200          // 1:200
    case metric_1_500          // 1:500
    case metric_1_1000         // 1:1000
    
    case fullSize              // 1:1
    case custom(CGFloat)       // Custom scale factor
    
    var description: String {
        switch self {
        case .architectural_1_16: return "1/16\"=1'-0\""
        case .architectural_1_8:  return "1/8\"=1'-0\""
        case .architectural_1_4:  return "1/4\"=1'-0\""
        case .architectural_1_2:  return "1/2\"=1'-0\""
        case .architectural_1_1:  return "1\"=1'-0\""
        case .engineering_1_10:   return "1\"=10'-0\""
        case .engineering_1_20:   return "1\"=20'-0\""
        case .engineering_1_50:   return "1\"=50'-0\""
        case .engineering_1_100:  return "1\"=100'-0\""
        case .metric_1_100:       return "1:100"
        case .metric_1_200:       return "1:200"
        case .metric_1_500:       return "1:500"
        case .metric_1_1000:      return "1:1000"
        case .fullSize:           return "1:1"
        case .custom(let factor): return "1:\(Int(1.0/factor))"
        }
    }
}

/// AutoCAD DWG versions (industry standard)
enum DWGVersion: String, CaseIterable {
    case r2004 = "AC1018"    // AutoCAD 2004-2006
    case r2007 = "AC1021"    // AutoCAD 2007-2009  
    case r2010 = "AC1024"    // AutoCAD 2010-2012
    case r2013 = "AC1027"    // AutoCAD 2013-2017
    case r2018 = "AC1032"    // AutoCAD 2018-2022
    case r2024 = "AC1035"    // AutoCAD 2024+
    
    var displayName: String {
        switch self {
        case .r2004: return "AutoCAD 2004-2006"
        case .r2007: return "AutoCAD 2007-2009"
        case .r2010: return "AutoCAD 2010-2012"
        case .r2013: return "AutoCAD 2013-2017"
        case .r2018: return "AutoCAD 2018-2022"
        case .r2024: return "AutoCAD 2024+"
        }
    }
}

/// AutoCAD line types (standard)
enum DWGLineType: String, CaseIterable {
    case continuous = "CONTINUOUS"
    case dashed = "DASHED"
    case dotted = "DOTTED"
    case dashDot = "DASHDOT"
    case center = "CENTER"
    case phantom = "PHANTOM"
    case hidden = "HIDDEN"
    
    var description: String {
        switch self {
        case .continuous: return "Continuous"
        case .dashed: return "Dashed"
        case .dotted: return "Dotted"
        case .dashDot: return "Dash-Dot"
        case .center: return "Center"
        case .phantom: return "Phantom"
        case .hidden: return "Hidden"
        }
    }
}

/// DWG entity structure (AutoCAD specification)
enum DWGEntity {
    case drawingInfo(bounds: CGRect, units: VectorUnit, scale: DWGScale, author: String, title: String, description: String?, dwgVersion: DWGVersion)
    case referenceRectangle(bounds: CGRect, units: VectorUnit, scale: DWGScale)
    case layerDefinition(name: String, index: Int, color: VectorColor, lineType: DWGLineType)
    case line(start: CGPoint, end: CGPoint, layer: String, color: VectorColor, lineWeight: CGFloat)
    case spline(startPoint: CGPoint, control1: CGPoint, control2: CGPoint, endPoint: CGPoint, layer: String, color: VectorColor, lineWeight: CGFloat)
    case region(points: [CGPoint], layer: String, fillColor: VectorColor)
}

/// DWG export content structure
struct DWGExportContent {
    let entities: [DWGEntity]
    let entityCount: Int
    let layerCount: Int
    let bounds: CGRect
    let scale: DWGScale
    let units: VectorUnit
    let dwgVersion: DWGVersion
}
