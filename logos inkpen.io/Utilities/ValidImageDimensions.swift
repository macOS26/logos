//
//  ValidImageDimensions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

/// Validates image dimensions to prevent Core Image crashes
func validateImageDimensions(_ size: CGSize) throws {
    guard size.width > 0 && size.height > 0 else {
        throw VectorImportError.parsingError("Image dimensions must be positive", line: nil)
    }
    
    // Core Image has limits on image dimensions
    let maxDimension: CGFloat = 16384 // 16K limit
    guard size.width <= maxDimension && size.height <= maxDimension else {
        throw VectorImportError.parsingError("Image dimensions exceed Core Image limits: \(size)", line: nil)
    }
    
    // Check for reasonable minimum size
    let minDimension: CGFloat = 1.0
    guard size.width >= minDimension && size.height >= minDimension else {
        throw VectorImportError.parsingError("Image dimensions too small: \(size)", line: nil)
    }
}
