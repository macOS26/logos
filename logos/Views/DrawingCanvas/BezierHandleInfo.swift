//
//  BezierHandleInfo.swift
//  logos
//
//  Created by Todd Bruss on 7/11/25.
//


// Professional bezier handle information
struct BezierHandleInfo {
    var control1: VectorPoint?
    var control2: VectorPoint?
    var hasHandles: Bool = false
}

// Point and handle identification
struct PointID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
}

struct HandleID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
    let handleType: HandleType
}

enum HandleType {
    case control1, control2
}
