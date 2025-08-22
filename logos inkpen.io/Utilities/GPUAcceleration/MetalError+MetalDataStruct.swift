//
//  MetalError+DataStruct.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Metal
import MetalKit
import Foundation

enum MetalError: Error {
    case libraryCreationFailed
    case pipelineCreationFailed
    case deviceNotAvailable
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case bufferCreationFailed
    case pipelineNotAvailable
    case shaderCompilationFailed
    case operationFailed(String)
}

// MARK: - Metal Data Structures
struct Point2D {
    let x: Float
    let y: Float
}

enum TrigonometricFunction: Int {
    case sine = 0
    case cosine = 1
    case tangent = 2
    case atan2 = 3
}

struct PolygonParams {
    let radius: Float
    let sides: UInt32
    let startAngle: Float
}
