//
//  handleShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    func handleShading(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let shadingName = String(cString: name)

            // CRITICAL: The current transformation matrix (CTM) contains the gradient rotation

            // Check if we have a pending clip operator - this means the W was for gradient, not image
            if hasClipOperatorPending {
                hasClipOperatorPending = false
                // The path is already in currentPath or compoundPathParts, will be used by gradient
                clipOperatorPath.removeAll()
                // Note: Don't clear compound path state here - it will be used by the gradient
            }

            // Create a shape with the shading gradient
            if let gradient = extractGradientFromShading(shadingName: shadingName, scanner: scanner) {
                // IMPROVED APPROACH: Use the shading within the current graphics context
                handleGradientInContext(gradient: gradient)
            }
        }
    }
}
