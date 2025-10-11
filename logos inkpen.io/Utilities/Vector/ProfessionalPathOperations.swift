import SwiftUI


extension ProfessionalPathOperations {

    static func professionalUnion(_ paths: [CGPath]) -> CGPath? {
        guard paths.count == 2 else { return nil }

        let validPaths = paths.filter { !$0.isEmpty }
        guard validPaths.count == 2 else { return nil }

        if let coreGraphicsResult = CoreGraphicsPathOperations.union(validPaths[0], validPaths[1], using: .winding) {
            return coreGraphicsResult
        } else {
            Log.error("❌ PROFESSIONAL UNION: CoreGraphics operation failed", category: .error)
            return nil
        }
    }


    static func professionalMinusFront(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        guard !frontPath.isEmpty && !backPath.isEmpty else { return backPath }

        if let coreGraphicsResult = CoreGraphicsPathOperations.subtract(frontPath, from: backPath, using: .winding) {
            return coreGraphicsResult
        }

        return nil
    }

    static func professionalIntersect(_ path1: CGPath, _ path2: CGPath) -> CGPath? {
        guard !path1.isEmpty && !path2.isEmpty else { return nil }

        if let coreGraphicsResult = CoreGraphicsPathOperations.intersection(path1, path2, using: .winding) {
            return coreGraphicsResult
        }

        return nil
    }

    static func professionalExclude(_ path1: CGPath, _ path2: CGPath) -> [CGPath] {
        guard !path1.isEmpty && !path2.isEmpty else {
            let nonEmptyPath = path1.isEmpty ? path2 : path1
            return nonEmptyPath.isEmpty ? [] : [nonEmptyPath]
        }

        if let coreGraphicsResult = CoreGraphicsPathOperations.symmetricDifference(path1, path2, using: .winding) {
            let components = CoreGraphicsPathOperations.componentsSeparated(coreGraphicsResult, using: .winding)
            if !components.isEmpty {
                return components
            } else {
                return [coreGraphicsResult]
            }
        }

        return []
    }


    static func professionalMosaic(_ paths: [CGPath]) -> [CGPath] {
        guard paths.count >= 2 else { return paths }


        let result = CoreGraphicsPathOperations.split(paths, using: .winding)

        if !result.isEmpty {
            return result
        } else {
            return []
            }
        }

    static func professionalCut(_ paths: [CGPath]) -> [CGPath] {
        guard paths.count >= 2 else { return paths }


        let result = CoreGraphicsPathOperations.cut(paths, using: .winding)

        if !result.isEmpty {
            return result
                } else {
            return []
            }
        }


    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }

        let sortedPoints = points.sorted { point1, point2 in
            if abs(point1.x - point2.x) < 1e-9 {
                return point1.y < point2.y
            }
            return point1.x < point2.x
        }

        var lower: [CGPoint] = []
        for point in sortedPoints {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }

        var upper: [CGPoint] = []
        for point in sortedPoints.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }

        lower.removeLast()
        upper.removeLast()

        return lower + upper
    }

    private static func cross(_ O: CGPoint, _ A: CGPoint, _ B: CGPoint) -> CGFloat {
        return (A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x)
    }


    static func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()

        cgPath.applyWithBlock { elementPtr in
            let element = elementPtr.pointee

            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])

            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])

            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])

            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])

            case .closeSubpath:
                currentPath.closeSubpath()

            @unknown default:
                break
            }
        }

        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }

        return subpaths
    }


    static func professionalMergeWithShapeTracking(_ paths: [CGPath], colors: [VectorColor]) -> [(CGPath, Int)] {
        guard paths.count >= 2 && colors.count == paths.count else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }


        let result = CoreGraphicsPathOperations.mergeWithShapeTracking(paths, colors: colors, using: .winding)

        if !result.isEmpty {
            return result
        } else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
    }

    static func professionalMerge(_ paths: [CGPath]) -> [CGPath] {
        guard paths.count >= 2 else { return paths }

        let validPaths = paths.filter { !$0.isEmpty }
        guard validPaths.count >= 2 else { return paths }


        var result = validPaths[0]
        for i in 1..<validPaths.count {
            if let unionResult = CoreGraphicsPathOperations.union(result, validPaths[i], using: .winding) {
                result = unionResult
            }
        }

        return [result]
    }

    static func professionalCropWithShapeTracking(_ paths: [CGPath]) -> [(CGPath, Int, Bool)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index, false) }
        }


        let result = CoreGraphicsPathOperations.cropWithShapeTracking(paths, using: .winding)

        if !result.isEmpty {
            return result
        } else {
            return []
        }
    }

    static func professionalCrop(_ paths: [CGPath]) -> [CGPath] {
        return professionalCropWithShapeTracking(paths).map { $0.0 }
    }

    static func professionalDieline(_ paths: [CGPath]) -> [CGPath] {
        guard !paths.isEmpty else { return [] }


        let splitPaths = professionalMosaic(paths)

        return splitPaths
    }

    static func professionalSeparate(_ paths: [CGPath]) -> [CGPath] {
        guard !paths.isEmpty else { return [] }


        var separatedPaths: [CGPath] = []

        for (_, path) in paths.enumerated() {
            let components = CoreGraphicsPathOperations.componentsSeparated(path, using: .winding)

            if components.count <= 1 {
                separatedPaths.append(path)
            } else {
                separatedPaths.append(contentsOf: components.filter { !$0.isEmpty })
            }
        }

        return separatedPaths
    }
}
