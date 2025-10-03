//
//  VectorColorExt.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

extension VectorColor {
    /// AutoCAD color index (ACI) mapping
    var autocadColorIndex: Int {
        // Standard AutoCAD Color Index (ACI) values
        // This is a simplified mapping - production would use full 255 color palette
        
        let red = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))
        let yellow = VectorColor.rgb(RGBColor(red: 1, green: 1, blue: 0, alpha: 1))
        let green = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0, alpha: 1))
        let cyan = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 1, alpha: 1))
        let blue = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1))
        let magenta = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1, alpha: 1))
        
        if self == red { return 1 }      // Red
        if self == yellow { return 2 }   // Yellow  
        if self == green { return 3 }    // Green
        if self == cyan { return 4 }     // Cyan
        if self == blue { return 5 }     // Blue
        if self == magenta { return 6 }  // Magenta
        if self == VectorColor.white { return 7 }    // White
        if self == VectorColor.black { return 0 }    // Black (default)
        
        // For custom colors, map to closest ACI color or use RGB
        return 7  // Default to white for unmapped colors
    }
}
