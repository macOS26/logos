//
//  SVGPathHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import Foundation

extension SVGParser {
    
    // MARK: - Path Helper Methods
    
    internal func parsePoints(_ pointsString: String) -> [CGPoint] {
        let coordinates = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        
        var points: [CGPoint] = []
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            points.append(CGPoint(x: coordinates[i], y: coordinates[i + 1]))
        }
        
        return points
    }
}