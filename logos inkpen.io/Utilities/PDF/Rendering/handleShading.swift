//
//  handleShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    func handleShading(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let shadingName = String(cString: name)
            print("PDF: Shading operation with shading: \(shadingName)")
            
            // CRITICAL: The current transformation matrix (CTM) contains the gradient rotation
            print("PDF: 🔍 GRADIENT APPLICATION - Current CTM rotation: \(atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi)°")
            
            // Create a shape with the shading gradient
            if let gradient = extractGradientFromShading(shadingName: shadingName, scanner: scanner) {
                // IMPROVED APPROACH: Use the shading within the current graphics context
                handleGradientInContext(gradient: gradient)
            }
        }
    }
}
