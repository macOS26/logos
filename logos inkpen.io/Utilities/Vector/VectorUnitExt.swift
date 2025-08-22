//
//  VectorUn.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Vector Unit Extensions

extension VectorUnit {
    /// Points per unit for professional conversion (AutoCAD standard)
    var pointsPerUnit_Export: CGFloat {
        switch self {
        case .points:      return 1.0        // 1 point = 1 point
        case .inches:      return 72.0       // 1 inch = 72 points
        case .millimeters: return 2.834646   // 1 mm = 2.834646 points
        case .pixels:      return 1.0        // Treat pixels as points for export
        case .picas:       return 12.0       // 1 pica = 12 points
        }
    }
    
    /// PROFESSIONAL MILLIMETER PRECISION CONVERSION (AutoCAD standards)
    var millimetersPerUnit: CGFloat {
        switch self {
        case .millimeters: return 1.0           // Base unit for precision
        case .inches:      return 25.4          // 1 inch = 25.4 mm (exact)
        case .points:      return 0.352777778   // 1 point = 0.352777778 mm (1/72 inch)
        case .picas:       return 4.233333333   // 1 pica = 4.233333333 mm (12 points)
        case .pixels:      return 0.352777778   // Treat pixels as points for CAD export
        }
    }
    
    /// Professional unit conversion with millimeter precision (6 decimal places)
    func convertTo(_ targetUnit: VectorUnit, value: CGFloat) -> CGFloat {
        let valueInMM = value * self.millimetersPerUnit
        let result = valueInMM / targetUnit.millimetersPerUnit
        
        // Round to millimeter precision (6 decimal places)
        return round(result * 1000000) / 1000000
    }
    
    /// Get professional scale factor for 100% scaling
    var scaleFactorFor100Percent: CGFloat {
        return 1.0  // 100% scaling means exactly 1:1 - no change
    }
}
