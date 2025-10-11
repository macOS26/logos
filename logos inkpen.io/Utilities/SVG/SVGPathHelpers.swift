import SwiftUI

extension SVGParser {


    func parsePoints(_ pointsString: String) -> [CGPoint] {
        let coordinates = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }

        var points: [CGPoint] = []
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            points.append(CGPoint(x: coordinates[i], y: coordinates[i + 1]))
        }

        return points
    }

    func tokenizeSVGPath(_ pathData: String) -> [String] {
        var tokens: [String] = []
        let chars = Array(pathData)
        var i = 0

        while i < chars.count {
            let char = chars[i]

            if char.isWhitespace || char == "," {
                i += 1
                continue
            }

            if char.isLetter {
                tokens.append(String(char))
                i += 1
                continue
            }

            if char.isNumber || char == "." || (char == "-" || char == "+") {
                var numberStr = ""
                var hasDecimal = false

                if char == "-" || char == "+" {
                    if i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == ".") {
                        numberStr.append(char)
                        i += 1
                    } else {
                        i += 1
                        continue
                    }
                }

                while i < chars.count {
                    let currentChar = chars[i]

                    if currentChar.isNumber {
                        numberStr.append(currentChar)
                        i += 1
                    } else if currentChar == "." && !hasDecimal {
                        if i + 1 < chars.count && chars[i + 1].isNumber || numberStr.isEmpty || numberStr == "-" || numberStr == "+" {
                            numberStr.append(currentChar)
                            hasDecimal = true
                            i += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }

                if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                    numberStr.append(chars[i])
                    i += 1

                    if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                        numberStr.append(chars[i])
                        i += 1
                    }

                    while i < chars.count && chars[i].isNumber {
                        numberStr.append(chars[i])
                        i += 1
                    }
                }

                if !numberStr.isEmpty && numberStr != "-" && numberStr != "+" {
                    tokens.append(numberStr)
                }
                continue
            }

            i += 1
        }

        return tokens
    }

    func parsePathData(_ pathData: String) -> [PathElement] {
        var elements: [PathElement] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint?


        let tokens = tokenizeSVGPath(pathData)

        var coordinateCount = 0
        var commandCount = 0
        for token in tokens {
            if token.rangeOfCharacter(from: .letters) != nil {
                commandCount += 1
            } else if Double(token) != nil {
                coordinateCount += 1
            }
        }

        var i = 0
        var currentCommand: String = ""

        while i < tokens.count {
            let token = tokens[i]

            if token.rangeOfCharacter(from: .letters) != nil {
                currentCommand = token
                i += 1

                if currentCommand == "Z" || currentCommand == "z" {
                    elements.append(.close)
                    currentPoint = subpathStart
                    lastControlPoint = nil
                }
                continue
            }

            switch currentCommand {
            case "M":
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "L"
                } else {
                    i += 1
                }

            case "m":
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "l"
                } else {
                    i += 1
                }

            case "L":
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }

            case "l":
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }

            case "H":
                if i < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }

            case "h":
                if i < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }

            case "V":
                if i < tokens.count {
                    let y = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }

            case "v":
                if i < tokens.count {
                    let dy = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    lastControlPoint = nil
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }

            case "C":
                if i + 5 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x2 = Double(tokens[i + 2]) ?? 0
                    let y2 = Double(tokens[i + 3]) ?? 0
                    let x = Double(tokens[i + 4]) ?? 0
                    let y = Double(tokens[i + 5]) ?? 0

                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)

                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }

            case "c":
                if i + 5 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx2 = Double(tokens[i + 2]) ?? 0
                    let dy2 = Double(tokens[i + 3]) ?? 0
                    let dx = Double(tokens[i + 4]) ?? 0
                    let dy = Double(tokens[i + 5]) ?? 0

                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    let x2 = currentPoint.x + dx2
                    let y2 = currentPoint.y + dy2
                    let newPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)


                    currentPoint = newPoint
                    lastControlPoint = CGPoint(x: x2, y: y2)

                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }

            case "S":
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let x2 = Double(tokens[i]) ?? 0
                    let y2 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0

                    let x1: Double
                    let y1: Double

                    if let lastCP = lastControlPoint {
                        x1 = 2 * currentPoint.x - lastCP.x
                        y1 = 2 * currentPoint.y - lastCP.y
                    } else {
                        x1 = currentPoint.x
                        y1 = currentPoint.y
                    }


                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)

                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 4
                }

            case "s":
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let dx2 = Double(tokens[i]) ?? 0
                    let dy2 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0

                    let reflectedX: Double
                    let reflectedY: Double

                    if let lastCP = lastControlPoint {
                        reflectedX = 2.0 * currentPoint.x - lastCP.x
                        reflectedY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        reflectedX = currentPoint.x
                        reflectedY = currentPoint.y
                    }

                    let secondControlX = currentPoint.x + dx2
                    let secondControlY = currentPoint.y + dy2

                    let endX = currentPoint.x + dx
                    let endY = currentPoint.y + dy

                    let firstControl = VectorPoint(reflectedX, reflectedY)
                    let secondControl = VectorPoint(secondControlX, secondControlY)
                    let endPointVector = VectorPoint(endX, endY)

                    currentPoint = CGPoint(x: endX, y: endY)
                    lastControlPoint = CGPoint(x: secondControlX, y: secondControlY)

                    let smoothCurveElement = PathElement.curve(
                        to: endPointVector,
                        control1: firstControl,
                        control2: secondControl
                    )

                    elements.append(smoothCurveElement)
                    i += 4
                }

            case "Q":
                if i + 3 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0

                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x1, y: y1)

                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }

            case "q":
                if i + 3 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0

                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = CGPoint(x: x1, y: y1)

                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }

            default:
                i += 1
            }
        }

        return elements
    }
}
