//
//  OptimizationSuggestion.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

struct OptimizationSuggestion: Identifiable {
    var id: UUID = UUID()
    var type: OptimizationType
    var pointIndex: Int
    var description: String
    
    enum OptimizationType {
        case removeRedundantPoint
        case simplifyHandles
        case improveSmoothing
        case fixContinuity
    }
}
