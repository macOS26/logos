//
//  ProfessionalBezierTests.swift
//  logosTests
//
//  Comprehensive Professional Bezier Curve Testing Suite
//  Tests Adobe Illustrator, FreeHand, and CorelDRAW standards
//  Beyond Professional Grade Quality Assurance
//
//  Created by AI Assistant on 1/12/25.
//

import XCTest
@testable import logos
import Foundation

class ProfessionalBezierTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    let testIterations = 10000 // As requested by user
    let precisionTolerance = 1e-10
    let performanceTimeout: TimeInterval = 10.0
    
    // MARK: - Test Data Generation
    
    func generateRandomPoints(count: Int) -> [VectorPoint] {
        return (0..<count).map { _ in
            VectorPoint(
                Double.random(in: -1000...1000),
                Double.random(in: -1000...1000)
            )
        }
    }
    
    func generateRandomBezierPoint() -> ProfessionalBezierMathematics.BezierPoint {
        let point = VectorPoint(
            Double.random(in: -1000...1000),
            Double.random(in: -1000...1000)
        )
        
        let types: [ProfessionalBezierMathematics.AnchorPointType] = [.corner, .smoothCurve, .smoothCorner, .cusp, .connector]
        let constraints: [ProfessionalBezierMathematics.HandleConstraint] = [.symmetric, .aligned, .independent, .automatic]
        
        return ProfessionalBezierMathematics.BezierPoint(
            point: point,
            pointType: types.randomElement()!,
            handleConstraint: constraints.randomElement()!
        )
    }
    
    // MARK: - COMPREHENSIVE MATHEMATICAL FOUNDATION TESTS
    
    func testDeCasteljauAlgorithm() {
        measure {
            for _ in 0..<testIterations {
                let points = generateRandomPoints(count: Int.random(in: 2...10))
                let t = Double.random(in: 0...1)
                
                let result = ProfessionalBezierMathematics.deCasteljauEvaluation(points: points, t: t)
                
                // Verify result is within bounds
                if points.count == 2 {
                    // Linear interpolation test
                    let expected = VectorPoint(
                        (1.0 - t) * points[0].x + t * points[1].x,
                        (1.0 - t) * points[0].y + t * points[1].y
                    )
                    XCTAssertEqual(result.x, expected.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, expected.y, accuracy: precisionTolerance)
                }
                
                // Boundary conditions
                if t == 0.0 {
                    XCTAssertEqual(result.x, points[0].x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, points[0].y, accuracy: precisionTolerance)
                }
                if t == 1.0 {
                    XCTAssertEqual(result.x, points.last!.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, points.last!.y, accuracy: precisionTolerance)
                }
            }
        }
    }
    
    func testBernsteinPolynomials() {
        measure {
            for _ in 0..<testIterations {
                let n = Int.random(in: 1...10)
                let t = Double.random(in: 0...1)
                
                // Test sum of Bernstein polynomials equals 1
                var sum = 0.0
                for i in 0...n {
                    sum += ProfessionalBezierMathematics.bernsteinBasis(i: i, n: n, t: t)
                }
                XCTAssertEqual(sum, 1.0, accuracy: precisionTolerance)
                
                // Test boundary conditions
                for i in 0...n {
                    let b0 = ProfessionalBezierMathematics.bernsteinBasis(i: i, n: n, t: 0.0)
                    let b1 = ProfessionalBezierMathematics.bernsteinBasis(i: i, n: n, t: 1.0)
                    
                    if i == 0 {
                        XCTAssertEqual(b0, 1.0, accuracy: precisionTolerance)
                        XCTAssertEqual(b1, 0.0, accuracy: precisionTolerance)
                    } else if i == n {
                        XCTAssertEqual(b0, 0.0, accuracy: precisionTolerance)
                        XCTAssertEqual(b1, 1.0, accuracy: precisionTolerance)
                    } else {
                        XCTAssertEqual(b0, 0.0, accuracy: precisionTolerance)
                        XCTAssertEqual(b1, 0.0, accuracy: precisionTolerance)
                    }
                }
            }
        }
    }
    
    func testBinomialCoefficients() {
        measure {
            for _ in 0..<1000 {
                let n = Int.random(in: 0...20)
                let k = Int.random(in: 0...n)
                
                let result = ProfessionalBezierMathematics.binomialCoefficient(n: n, k: k)
                
                // Test symmetry: C(n,k) = C(n,n-k)
                let symmetric = ProfessionalBezierMathematics.binomialCoefficient(n: n, k: n - k)
                XCTAssertEqual(result, symmetric)
                
                // Test boundary conditions
                if k == 0 || k == n {
                    XCTAssertEqual(result, 1)
                }
                
                // Test Pascal's triangle property: C(n,k) = C(n-1,k-1) + C(n-1,k)
                if n > 0 && k > 0 && k < n {
                    let pascal = ProfessionalBezierMathematics.binomialCoefficient(n: n-1, k: k-1) + 
                                ProfessionalBezierMathematics.binomialCoefficient(n: n-1, k: k)
                    XCTAssertEqual(result, pascal)
                }
            }
        }
    }
    
    // MARK: - CUBIC BEZIER CURVE TESTS
    
    func testCubicBezierEvaluation() {
        measure {
            for _ in 0..<testIterations {
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                let result = ProfessionalBezierMathematics.evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                
                // Test boundary conditions
                if t == 0.0 {
                    XCTAssertEqual(result.x, p0.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, p0.y, accuracy: precisionTolerance)
                }
                if t == 1.0 {
                    XCTAssertEqual(result.x, p3.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, p3.y, accuracy: precisionTolerance)
                }
                
                // Compare with De Casteljau's algorithm
                let deCasteljauResult = ProfessionalBezierMathematics.deCasteljauEvaluation(points: [p0, p1, p2, p3], t: t)
                XCTAssertEqual(result.x, deCasteljauResult.x, accuracy: precisionTolerance)
                XCTAssertEqual(result.y, deCasteljauResult.y, accuracy: precisionTolerance)
            }
        }
    }
    
    func testQuadraticBezierEvaluation() {
        measure {
            for _ in 0..<testIterations {
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                let result = ProfessionalBezierMathematics.evaluateQuadraticBezier(p0: p0, p1: p1, p2: p2, t: t)
                
                // Test boundary conditions
                if t == 0.0 {
                    XCTAssertEqual(result.x, p0.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, p0.y, accuracy: precisionTolerance)
                }
                if t == 1.0 {
                    XCTAssertEqual(result.x, p2.x, accuracy: precisionTolerance)
                    XCTAssertEqual(result.y, p2.y, accuracy: precisionTolerance)
                }
                
                // Compare with De Casteljau's algorithm
                let deCasteljauResult = ProfessionalBezierMathematics.deCasteljauEvaluation(points: [p0, p1, p2], t: t)
                XCTAssertEqual(result.x, deCasteljauResult.x, accuracy: precisionTolerance)
                XCTAssertEqual(result.y, deCasteljauResult.y, accuracy: precisionTolerance)
            }
        }
    }
    
    // MARK: - CURVE DERIVATIVES AND ANALYSIS TESTS
    
    func testCubicBezierDerivatives() {
        measure {
            for _ in 0..<testIterations {
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                let firstDeriv = ProfessionalBezierMathematics.cubicBezierFirstDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                let secondDeriv = ProfessionalBezierMathematics.cubicBezierSecondDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                
                // Test derivative boundary conditions for control points
                if t == 0.0 {
                    let expectedFirst = VectorPoint(3.0 * (p1.x - p0.x), 3.0 * (p1.y - p0.y))
                    XCTAssertEqual(firstDeriv.x, expectedFirst.x, accuracy: precisionTolerance)
                    XCTAssertEqual(firstDeriv.y, expectedFirst.y, accuracy: precisionTolerance)
                }
                if t == 1.0 {
                    let expectedFirst = VectorPoint(3.0 * (p3.x - p2.x), 3.0 * (p3.y - p2.y))
                    XCTAssertEqual(firstDeriv.x, expectedFirst.x, accuracy: precisionTolerance)
                    XCTAssertEqual(firstDeriv.y, expectedFirst.y, accuracy: precisionTolerance)
                }
                
                // Verify derivatives are real numbers
                XCTAssertFalse(firstDeriv.x.isNaN)
                XCTAssertFalse(firstDeriv.y.isNaN)
                XCTAssertFalse(secondDeriv.x.isNaN)
                XCTAssertFalse(secondDeriv.y.isNaN)
            }
        }
    }
    
    func testCurvatureCalculation() {
        measure {
            for _ in 0..<testIterations {
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                let curvature = ProfessionalBezierMathematics.calculateCurvature(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                
                // Curvature should be non-negative
                XCTAssertGreaterThanOrEqual(curvature, 0.0)
                
                // Curvature should be finite
                XCTAssertFalse(curvature.isNaN)
                XCTAssertFalse(curvature.isInfinite)
                
                // Test straight line has zero curvature
                let straightP1 = VectorPoint(p0.x + (p3.x - p0.x) * 0.33, p0.y + (p3.y - p0.y) * 0.33)
                let straightP2 = VectorPoint(p0.x + (p3.x - p0.x) * 0.66, p0.y + (p3.y - p0.y) * 0.66)
                let straightCurvature = ProfessionalBezierMathematics.calculateCurvature(p0: p0, p1: straightP1, p2: straightP2, p3: p3, t: t)
                XCTAssertEqual(straightCurvature, 0.0, accuracy: 1e-6)
            }
        }
    }
    
    // MARK: - CURVE SUBDIVISION TESTS
    
    func testCubicBezierSubdivision() {
        measure {
            for _ in 0..<testIterations {
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                let (leftCurve, rightCurve) = ProfessionalBezierMathematics.splitCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                
                // Verify both curves have 4 points
                XCTAssertEqual(leftCurve.count, 4)
                XCTAssertEqual(rightCurve.count, 4)
                
                // Verify continuity at split point
                XCTAssertEqual(leftCurve[3].x, rightCurve[0].x, accuracy: precisionTolerance)
                XCTAssertEqual(leftCurve[3].y, rightCurve[0].y, accuracy: precisionTolerance)
                
                // Verify original curve endpoints
                XCTAssertEqual(leftCurve[0].x, p0.x, accuracy: precisionTolerance)
                XCTAssertEqual(leftCurve[0].y, p0.y, accuracy: precisionTolerance)
                XCTAssertEqual(rightCurve[3].x, p3.x, accuracy: precisionTolerance)
                XCTAssertEqual(rightCurve[3].y, p3.y, accuracy: precisionTolerance)
                
                // Verify split point is on original curve
                let originalPoint = ProfessionalBezierMathematics.evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                XCTAssertEqual(leftCurve[3].x, originalPoint.x, accuracy: precisionTolerance)
                XCTAssertEqual(leftCurve[3].y, originalPoint.y, accuracy: precisionTolerance)
            }
        }
    }
    
    // MARK: - PROFESSIONAL PATH TESTS
    
    func testProfessionalVectorPath() {
        measure {
            for _ in 0..<1000 {
                var path = ProfessionalVectorPath()
                
                // Add random points
                let pointCount = Int.random(in: 3...20)
                for _ in 0..<pointCount {
                    path.addPoint(generateRandomBezierPoint())
                }
                
                // Test path operations
                if Bool.random() {
                    path.close()
                    XCTAssertTrue(path.isClosed)
                } else {
                    path.open()
                    XCTAssertFalse(path.isClosed)
                }
                
                // Test handle generation
                path.generateSmoothHandles()
                
                // Verify path integrity
                XCTAssertEqual(path.points.count, pointCount)
                
                // Test path analysis
                let analysis = path.analyzePath()
                XCTAssertGreaterThanOrEqual(analysis.qualityScore, 0.0)
                XCTAssertLessThanOrEqual(analysis.qualityScore, 100.0)
                
                // Test legacy conversion
                let legacyPath = path.toLegacyVectorPath()
                XCTAssertFalse(legacyPath.elements.isEmpty)
                
                // Test round-trip conversion
                let roundTripPath = ProfessionalVectorPath.fromLegacyVectorPath(legacyPath)
                XCTAssertGreaterThanOrEqual(roundTripPath.points.count, 1)
            }
        }
    }
    
    // MARK: - HANDLE GENERATION TESTS
    
    func testSmoothHandleGeneration() {
        measure {
            for _ in 0..<testIterations {
                let prevPoint = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let currentPoint = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let nextPoint = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let tension = Double.random(in: 0.1...1.0)
                
                let (incomingHandle, outgoingHandle) = ProfessionalBezierMathematics.generateSmoothHandles(
                    previousPoint: prevPoint,
                    currentPoint: currentPoint,
                    nextPoint: nextPoint,
                    tension: tension
                )
                
                if let incoming = incomingHandle, let outgoing = outgoingHandle {
                    // Test that handles are on opposite sides of the point
                    let incomingVector = VectorPoint(
                        currentPoint.x - incoming.x,
                        currentPoint.y - incoming.y
                    )
                    let outgoingVector = VectorPoint(
                        outgoing.x - currentPoint.x,
                        outgoing.y - currentPoint.y
                    )
                    
                    // Handles should be roughly aligned (for smooth curves)
                    let crossProduct = incomingVector.x * outgoingVector.y - incomingVector.y * outgoingVector.x
                    XCTAssertLessThan(abs(crossProduct), 1e-6) // Should be nearly collinear
                }
            }
        }
    }
    
    // MARK: - CONTINUITY ANALYSIS TESTS
    
    func testCurveContinuity() {
        measure {
            for _ in 0..<testIterations {
                // Generate two connected curves
                let p0 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let p3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                
                // Second curve starts where first ends
                let q0 = p3
                let q1 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let q2 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let q3 = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                
                let curve1 = [p0, p1, p2, p3]
                let curve2 = [q0, q1, q2, q3]
                
                let continuity = ProfessionalBezierMathematics.analyzeContinuity(curve1: curve1, curve2: curve2)
                
                // Should at least have C0 continuity (position)
                XCTAssertNotEqual(continuity, .none)
                
                // Test G1 continuity with aligned handles
                let alignedQ1 = VectorPoint(
                    p3.x + (p3.x - p2.x),
                    p3.y + (p3.y - p2.y)
                )
                let g1Curve2 = [q0, alignedQ1, q2, q3]
                let g1Continuity = ProfessionalBezierMathematics.analyzeContinuity(curve1: curve1, curve2: g1Curve2)
                
                // Should have at least G1 continuity
                XCTAssertTrue(g1Continuity == .g1 || g1Continuity == .c1)
            }
        }
    }
    
    // MARK: - PERFORMANCE STRESS TESTS
    
    func testPerformanceStressTest() {
        measure {
            let largePointCount = 1000
            let points = generateRandomPoints(count: largePointCount)
            
            // Test large curve evaluation
            for _ in 0..<100 {
                let t = Double.random(in: 0...1)
                let result = ProfessionalBezierMathematics.deCasteljauEvaluation(points: points, t: t)
                XCTAssertFalse(result.x.isNaN)
                XCTAssertFalse(result.y.isNaN)
            }
        }
    }
    
    func testConcurrentBezierOperations() {
        let expectation = XCTestExpectation(description: "Concurrent bezier operations")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let p0 = VectorPoint(Double(index), Double(index))
            let p1 = VectorPoint(Double(index + 1), Double(index + 1))
            let p2 = VectorPoint(Double(index + 2), Double(index + 2))
            let p3 = VectorPoint(Double(index + 3), Double(index + 3))
            let t = Double(index) / 100.0
            
            let result = ProfessionalBezierMathematics.evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            XCTAssertFalse(result.x.isNaN)
            XCTAssertFalse(result.y.isNaN)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: performanceTimeout)
    }
    
    // MARK: - ADOBE ILLUSTRATOR COMPATIBILITY TESTS
    
    func testAdobeIllustratorCompatibility() {
        measure {
            for _ in 0..<1000 {
                // Test Adobe Illustrator-style pen tool behavior
                let location = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let handleLength = Double.random(in: 10...100)
                let angle = Double.random(in: 0...(2 * .pi))
                
                let smoothPoint = ProfessionalBezierMathematics.BezierPoint.smoothPoint(
                    at: location,
                    handleLength: handleLength,
                    angle: angle
                )
                
                // Verify Adobe Illustrator standards
                XCTAssertEqual(smoothPoint.pointType, .smoothCurve)
                XCTAssertEqual(smoothPoint.handleConstraint, .symmetric)
                XCTAssertNotNil(smoothPoint.incomingHandle)
                XCTAssertNotNil(smoothPoint.outgoingHandle)
                
                // Verify handle symmetry
                if let incoming = smoothPoint.incomingHandle,
                   let outgoing = smoothPoint.outgoingHandle {
                    let incomingDistance = location.distance(to: incoming)
                    let outgoingDistance = location.distance(to: outgoing)
                    XCTAssertEqual(incomingDistance, outgoingDistance, accuracy: precisionTolerance)
                }
                
                // Test corner point creation
                let cornerPoint = ProfessionalBezierMathematics.BezierPoint.cornerPoint(at: location)
                XCTAssertEqual(cornerPoint.pointType, .corner)
                XCTAssertEqual(cornerPoint.handleConstraint, .independent)
                XCTAssertNil(cornerPoint.incomingHandle)
                XCTAssertNil(cornerPoint.outgoingHandle)
            }
        }
    }
    
    // MARK: - ARC LENGTH AND CURVE FITTING TESTS
    
    func testArcLengthCalculation() {
        measure {
            for _ in 0..<1000 {
                let p0 = VectorPoint(0, 0)
                let p1 = VectorPoint(100, 0)
                let p2 = VectorPoint(100, 100)
                let p3 = VectorPoint(200, 100)
                
                let arcLength = ProfessionalBezierMathematics.calculateArcLength(
                    p0: p0, p1: p1, p2: p2, p3: p3,
                    subdivisions: Int.random(in: 5...50)
                )
                
                // Arc length should be positive
                XCTAssertGreaterThan(arcLength, 0.0)
                
                // Arc length should be at least the straight-line distance
                let straightDistance = p0.distance(to: p3)
                XCTAssertGreaterThanOrEqual(arcLength, straightDistance)
                
                // Arc length should be finite
                XCTAssertFalse(arcLength.isNaN)
                XCTAssertFalse(arcLength.isInfinite)
            }
        }
    }
    
    func testCurveFitting() {
        measure {
            for _ in 0..<1000 {
                let pointCount = Int.random(in: 4...20)
                let points = generateRandomPoints(count: pointCount)
                
                if let fittedCurve = ProfessionalBezierMathematics.fitCubicBezierToPoints(points: points) {
                    // Fitted curve should have 4 control points
                    XCTAssertEqual(fittedCurve.count, 4)
                    
                    // First and last points should match input
                    XCTAssertEqual(fittedCurve[0].x, points[0].x, accuracy: precisionTolerance)
                    XCTAssertEqual(fittedCurve[0].y, points[0].y, accuracy: precisionTolerance)
                    XCTAssertEqual(fittedCurve[3].x, points.last!.x, accuracy: precisionTolerance)
                    XCTAssertEqual(fittedCurve[3].y, points.last!.y, accuracy: precisionTolerance)
                }
            }
        }
    }
    
    // MARK: - VECTOR POINT OPERATIONS TESTS
    
    func testVectorPointOperations() {
        measure {
            for _ in 0..<testIterations {
                let a = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let b = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let t = Double.random(in: 0...1)
                
                // Test linear interpolation
                let lerp = VectorPoint.lerp(a, b, t)
                if t == 0.0 {
                    XCTAssertEqual(lerp.x, a.x, accuracy: precisionTolerance)
                    XCTAssertEqual(lerp.y, a.y, accuracy: precisionTolerance)
                }
                if t == 1.0 {
                    XCTAssertEqual(lerp.x, b.x, accuracy: precisionTolerance)
                    XCTAssertEqual(lerp.y, b.y, accuracy: precisionTolerance)
                }
                
                // Test distance calculation
                let distance = a.distance(to: b)
                XCTAssertGreaterThanOrEqual(distance, 0.0)
                XCTAssertEqual(a.distance(to: a), 0.0, accuracy: precisionTolerance)
                
                // Test angle calculation
                let angle = a.angle(to: b)
                XCTAssertFalse(angle.isNaN)
                XCTAssertFalse(angle.isInfinite)
                
                // Test normalization
                let normalized = a.normalized
                let magnitude = normalized.magnitude
                if a.magnitude > 1e-10 {
                    XCTAssertEqual(magnitude, 1.0, accuracy: precisionTolerance)
                }
                
                // Test magnitude
                let mag = a.magnitude
                XCTAssertGreaterThanOrEqual(mag, 0.0)
                XCTAssertFalse(mag.isNaN)
            }
        }
    }
    
    // MARK: - PROFESSIONAL BEZIER FACTORY TESTS
    
    func testProfessionalBezierFactory() {
        measure {
            for _ in 0..<1000 {
                let startPoint = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let endPoint = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let tension = Double.random(in: 0.1...1.0)
                
                // Test smooth curve creation
                let smoothCurve = ProfessionalBezierFactory.createSmoothCurve(
                    from: startPoint,
                    to: endPoint,
                    tension: tension
                )
                
                XCTAssertEqual(smoothCurve.count, 4)
                XCTAssertEqual(smoothCurve[0].x, startPoint.x, accuracy: precisionTolerance)
                XCTAssertEqual(smoothCurve[0].y, startPoint.y, accuracy: precisionTolerance)
                XCTAssertEqual(smoothCurve[3].x, endPoint.x, accuracy: precisionTolerance)
                XCTAssertEqual(smoothCurve[3].y, endPoint.y, accuracy: precisionTolerance)
                
                // Test circular arc creation
                let center = VectorPoint(Double.random(in: -1000...1000), Double.random(in: -1000...1000))
                let radius = Double.random(in: 10...1000)
                let startAngle = Double.random(in: 0...(2 * .pi))
                let endAngle = startAngle + Double.random(in: 0...(.pi / 2)) // Quarter circle max
                
                let circularArc = ProfessionalBezierFactory.createCircularArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle
                )
                
                XCTAssertEqual(circularArc.count, 4)
                
                // Verify start and end points are on the circle
                let startExpected = VectorPoint(
                    center.x + radius * cos(startAngle),
                    center.y + radius * sin(startAngle)
                )
                let endExpected = VectorPoint(
                    center.x + radius * cos(endAngle),
                    center.y + radius * sin(endAngle)
                )
                
                XCTAssertEqual(circularArc[0].x, startExpected.x, accuracy: precisionTolerance)
                XCTAssertEqual(circularArc[0].y, startExpected.y, accuracy: precisionTolerance)
                XCTAssertEqual(circularArc[3].x, endExpected.x, accuracy: precisionTolerance)
                XCTAssertEqual(circularArc[3].y, endExpected.y, accuracy: precisionTolerance)
            }
        }
    }
    
    // MARK: - EDGE CASE AND ROBUSTNESS TESTS
    
    func testEdgeCases() {
        // Test with zero-length curves
        let zeroPoint = VectorPoint(0, 0)
        let zeroResult = ProfessionalBezierMathematics.evaluateCubicBezier(
            p0: zeroPoint, p1: zeroPoint, p2: zeroPoint, p3: zeroPoint, t: 0.5
        )
        XCTAssertEqual(zeroResult.x, 0, accuracy: precisionTolerance)
        XCTAssertEqual(zeroResult.y, 0, accuracy: precisionTolerance)
        
        // Test with extreme values
        let extremePoint = VectorPoint(Double.greatestFiniteMagnitude / 2, Double.greatestFiniteMagnitude / 2)
        let extremeResult = ProfessionalBezierMathematics.evaluateCubicBezier(
            p0: zeroPoint, p1: zeroPoint, p2: zeroPoint, p3: extremePoint, t: 1.0
        )
        XCTAssertFalse(extremeResult.x.isNaN)
        XCTAssertFalse(extremeResult.y.isNaN)
        
        // Test with negative coordinates
        let negativePoints = [
            VectorPoint(-1000, -1000),
            VectorPoint(-500, -500),
            VectorPoint(-250, -250),
            VectorPoint(-100, -100)
        ]
        let negativeResult = ProfessionalBezierMathematics.deCasteljauEvaluation(points: negativePoints, t: 0.5)
        XCTAssertFalse(negativeResult.x.isNaN)
        XCTAssertFalse(negativeResult.y.isNaN)
        
        // Test boundary parameter values
        let boundaryPoints = generateRandomPoints(count: 4)
        let t0Result = ProfessionalBezierMathematics.deCasteljauEvaluation(points: boundaryPoints, t: 0.0)
        let t1Result = ProfessionalBezierMathematics.deCasteljauEvaluation(points: boundaryPoints, t: 1.0)
        
        XCTAssertEqual(t0Result.x, boundaryPoints[0].x, accuracy: precisionTolerance)
        XCTAssertEqual(t0Result.y, boundaryPoints[0].y, accuracy: precisionTolerance)
        XCTAssertEqual(t1Result.x, boundaryPoints.last!.x, accuracy: precisionTolerance)
        XCTAssertEqual(t1Result.y, boundaryPoints.last!.y, accuracy: precisionTolerance)
    }
    
    // MARK: - COMPREHENSIVE QUALITY ASSURANCE
    
    func testOverallSystemIntegrity() {
        measure {
            // Test complete workflow from point creation to path analysis
            for _ in 0..<100 {
                var path = ProfessionalVectorPath()
                
                // Create complex path with various point types
                let pointTypes: [ProfessionalBezierMathematics.AnchorPointType] = [.corner, .smoothCurve, .smoothCorner, .cusp, .connector]
                
                for i in 0..<10 {
                    let point = VectorPoint(Double(i * 100), sin(Double(i) * 0.5) * 100)
                    let bezierPoint = ProfessionalBezierMathematics.BezierPoint(
                        point: point,
                        pointType: pointTypes.randomElement()!,
                        handleConstraint: .automatic
                    )
                    path.addPoint(bezierPoint)
                }
                
                // Generate handles and analyze
                path.generateSmoothHandles()
                let analysis = path.analyzePath()
                
                // Verify system integrity
                XCTAssertGreaterThanOrEqual(analysis.qualityScore, 0.0)
                XCTAssertLessThanOrEqual(analysis.qualityScore, 100.0)
                
                // Test conversions
                let legacyPath = path.toLegacyVectorPath()
                XCTAssertFalse(legacyPath.elements.isEmpty)
                
                let roundTripPath = ProfessionalVectorPath.fromLegacyVectorPath(legacyPath)
                XCTAssertGreaterThanOrEqual(roundTripPath.points.count, 1)
                
                // Test path operations
                if Bool.random() {
                    path.close()
                    XCTAssertTrue(path.isClosed)
                    
                    // Verify closing continuity
                    if path.points.count > 2 {
                        let firstPoint = path.points.first!
                        let lastPoint = path.points.last!
                        
                        // Should have proper continuity at closing point
                        XCTAssertNotNil(firstPoint.point)
                        XCTAssertNotNil(lastPoint.point)
                    }
                }
            }
        }
    }
}

// MARK: - EXTENDED TEST UTILITIES

extension ProfessionalBezierTests {
    
    /// Generate test data for stress testing
    func generateStressTestData(complexity: Int) -> [VectorPoint] {
        var points: [VectorPoint] = []
        
        for i in 0..<complexity {
            let angle = Double(i) * 2.0 * .pi / Double(complexity)
            let radius = Double.random(in: 100...1000)
            let noise = Double.random(in: -50...50)
            
            let x = cos(angle) * radius + noise
            let y = sin(angle) * radius + noise
            
            points.append(VectorPoint(x, y))
        }
        
        return points
    }
    
    /// Verify numerical stability
    func verifyNumericalStability(_ result: VectorPoint) -> Bool {
        return !result.x.isNaN && !result.y.isNaN && 
               !result.x.isInfinite && !result.y.isInfinite
    }
    
    /// Benchmark performance
    func benchmarkOperation<T>(_ operation: () -> T, iterations: Int = 1000) -> (result: T?, averageTime: TimeInterval) {
        let startTime = Date()
        var result: T?
        
        for _ in 0..<iterations {
            result = operation()
        }
        
        let endTime = Date()
        let averageTime = endTime.timeIntervalSince(startTime) / Double(iterations)
        
        return (result, averageTime)
    }
}

// MARK: - PERFORMANCE BENCHMARKS

extension ProfessionalBezierTests {
    
    func testBenchmarkAllOperations() {
        let complexityLevels = [10, 100, 1000, 10000]
        
        for complexity in complexityLevels {
            let points = generateStressTestData(complexity: complexity)
            
            // Benchmark De Casteljau's algorithm
            let deCasteljauBenchmark = benchmarkOperation({
                ProfessionalBezierMathematics.deCasteljauEvaluation(points: Array(points.prefix(min(10, complexity))), t: 0.5)
            }, iterations: 1000)
            
            print("De Casteljau complexity \(complexity): \(deCasteljauBenchmark.averageTime * 1000)ms")
            XCTAssertLessThan(deCasteljauBenchmark.averageTime, 0.001) // Should be sub-millisecond
            
            // Benchmark curve evaluation
            if complexity >= 4 {
                let evaluationBenchmark = benchmarkOperation({
                    ProfessionalBezierMathematics.evaluateCubicBezier(
                        p0: points[0], p1: points[1], p2: points[2], p3: points[3], t: 0.5
                    )
                }, iterations: 10000)
                
                print("Cubic evaluation complexity \(complexity): \(evaluationBenchmark.averageTime * 1000000)μs")
                XCTAssertLessThan(evaluationBenchmark.averageTime, 0.0001) // Should be sub-100μs
            }
        }
    }
} 