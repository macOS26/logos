//
//  VectorGradientExt.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - CoreGraphics Extension for Gradient Rendering

extension VectorGradient {
    /// Convert VectorGradient to CGGradient for rendering
    func createCGGradient() -> CGGradient? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var locations: [CGFloat] = []
        var colors: [CGFloat] = []
        
        for stop in stops {
            locations.append(CGFloat(stop.position))
            
            // Extract RGB components from the color
            switch stop.color {
            case .rgb(let rgb):
                colors.append(contentsOf: [CGFloat(rgb.red), CGFloat(rgb.green), CGFloat(rgb.blue), CGFloat(rgb.alpha * stop.opacity)])
            case .cmyk(let cmyk):
                // Convert CMYK to RGB
                let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
                let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                colors.append(contentsOf: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(stop.opacity)])
            default:
                // Default to black for other color types
                colors.append(contentsOf: [0, 0, 0, CGFloat(stop.opacity)])
            }
        }
        
        return CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: stops.count
        )
    }
    
    /// Apply gradient fill to a CoreGraphics context
    func fill(in context: CGContext, bounds: CGRect) {
        guard let gradient = createCGGradient() else { return }
        
        context.saveGState()
        
        switch self {
        case .linear(let linear):
            let startPoint = CGPoint(
                x: bounds.minX + linear.startPoint.x * bounds.width,
                y: bounds.minY + linear.startPoint.y * bounds.height
            )
            let endPoint = CGPoint(
                x: bounds.minX + linear.endPoint.x * bounds.width,
                y: bounds.minY + linear.endPoint.y * bounds.height
            )
            
            context.drawLinearGradient(
                gradient,
                start: startPoint,
                end: endPoint,
                options: linear.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            
        case .radial(let radial):
            let centerPoint = CGPoint(
                x: bounds.minX + radial.centerPoint.x * bounds.width,
                y: bounds.minY + radial.centerPoint.y * bounds.height
            )
            let radius = CGFloat(radial.radius) * max(bounds.width, bounds.height)
            
            if let focalPoint = radial.focalPoint {
                let focal = CGPoint(
                    x: bounds.minX + focalPoint.x * bounds.width,
                    y: bounds.minY + focalPoint.y * bounds.height
                )
                context.drawRadialGradient(
                    gradient,
                    startCenter: focal,
                    startRadius: 0,
                    endCenter: centerPoint,
                    endRadius: radius,
                    options: radial.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            } else {
                context.drawRadialGradient(
                    gradient,
                    startCenter: centerPoint,
                    startRadius: 0,
                    endCenter: centerPoint,
                    endRadius: radius,
                    options: radial.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }
        
        context.restoreGState()
    }
}
