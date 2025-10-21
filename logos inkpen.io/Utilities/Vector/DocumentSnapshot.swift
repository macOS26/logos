import Foundation

struct DocumentSnapshot: Equatable, Codable {
    var objects: [UUID: VectorObject]
    var layers: [Layer]  // In stack order

    init(objects: [UUID: VectorObject] = [:], layers: [Layer] = []) {
        self.objects = objects
        self.layers = layers
    }
}
