//
//  RectangleIcon.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

struct RectangleIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let rect = CGRect(x: 4 - IconStrokeExpand, y: 6 - IconStrokeExpand, width: 12 + IconStrokeWidth, height: 8 + IconStrokeWidth)
            path.addRect(rect)
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
