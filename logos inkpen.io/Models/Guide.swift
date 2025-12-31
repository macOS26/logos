import SwiftUI

/// Represents a guide line (horizontal or vertical) for alignment
struct Guide: Identifiable, Codable, Equatable {
    let id: UUID
    var position: CGFloat  // X position for vertical, Y position for horizontal
    var orientation: Orientation

    enum Orientation: String, Codable {
        case horizontal
        case vertical
    }

    init(id: UUID = UUID(), position: CGFloat, orientation: Orientation) {
        self.id = id
        self.position = position
        self.orientation = orientation
    }
}

/// Non-photo blue color for guides (traditional graphic design color)
extension Color {
    static let nonPhotoBlue = Color(red: 164/255, green: 221/255, blue: 237/255)  // #a4dded
    static let nonPhotoBlueSelected = Color(red: 114/255, green: 188/255, blue: 218/255)  // Slightly darker blue for selected guides
}
