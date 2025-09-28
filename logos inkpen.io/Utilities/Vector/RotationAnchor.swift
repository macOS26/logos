//
//  RotationAnchor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

enum RotationAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var displayName: String {
        return self.rawValue
    }
}
