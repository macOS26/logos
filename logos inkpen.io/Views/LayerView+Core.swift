//
//  LayerView+Core.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Core LayerView Extensions

// This file contains extensions and helper methods for LayerView
// The main LayerView struct is defined in LayerView.swift

// MARK: - Gradient Rendering Helper Functions

/// Helper functions to convert VectorGradient to SwiftUI gradient objects
extension ShapeView {
    
    /// Creates appropriate fill rendering based on VectorColor type
    @ViewBuilder
    private func renderFill(fillStyle: FillStyle, path: Path, shape: VectorShape) -> some View {
        switch fillStyle.color {
        case .gradient(let vectorGradient):
            // Use the new NSViewRepresentable view for correct gradient rendering
            GradientFillView(gradient: vectorGradient, path: path.cgPath)
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
            
        default:
            path.fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule == .evenOdd))
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
        }
    }
    
    /// Creates appropriate stroke rendering based on VectorColor type
    @ViewBuilder
    private func renderStrokeColor(strokeStyle: StrokeStyle, path: Path, swiftUIStyle: SwiftUI.StrokeStyle, shape: VectorShape) -> some View {
        switch strokeStyle.color {
        case .gradient(let vectorGradient):
            // Use NSView-based gradient stroke rendering
            GradientStrokeView(gradient: vectorGradient, path: path.cgPath, strokeStyle: strokeStyle)
            
        default:
            path.stroke(strokeStyle.color.color, style: swiftUIStyle)
        }
    }

    // Helper function to create pre-transformed paths for clipping masks
    private func createPreTransformedPath(for shape: VectorShape) -> CGPath {
        let path = CGMutablePath()
        
        // Add path elements
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }
        
        // RESTORE: Apply shape transform for proper positioning
        // The paths need to include transforms to align with the image
        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }
        
        return path
    }
}

// Note: Extension methods for BlendMode, CGLineCap, and CGLineJoin are already defined
// in the main LayerView.swift file to avoid duplicate declarations.