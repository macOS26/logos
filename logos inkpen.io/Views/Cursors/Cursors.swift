import SwiftUI

private func makeHaloCursor(symbolName: String, pointSize: CGFloat, originalHotspot: CGPoint) -> NSCursor {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return .crosshair }
    let baseConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
    let blackConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.black])
    let whiteSymbol = (base.withSymbolConfiguration(baseConfig.applying(whiteConfig)) ?? base)
    let blackSymbol = (base.withSymbolConfiguration(baseConfig.applying(blackConfig)) ?? base)
    let padding: CGFloat = 10
    let symbolSize = blackSymbol.size
    let destRect = CGRect(x: padding, y: padding, width: symbolSize.width, height: symbolSize.height)
    let newSize = NSSize(width: symbolSize.width + padding * 2, height: symbolSize.height + padding * 2)
    let composed = NSImage(size: newSize)
    composed.lockFocus()
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    whiteSymbol.draw(in: destRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    blackSymbol.draw(in: destRect)

    composed.unlockFocus()

    let hotspot = CGPoint(x: padding + originalHotspot.x, y: padding + originalHotspot.y)
    return NSCursor(image: composed, hotSpot: hotspot)
}

let EyedropperCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 4, y: 16)
    return makeHaloCursor(symbolName: "eyedropper", pointSize: 18, originalHotspot: originalHotspot)
}()

let MagnifyingGlassCursor: NSCursor = {
    guard let base = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) else { return .crosshair }
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let symbol = base.withSymbolConfiguration(config) ?? base
    let center = CGPoint(x: symbol.size.width * 0.35, y: symbol.size.height * 0.35)
    return makeHaloCursor(symbolName: "magnifyingglass", pointSize: 18, originalHotspot: center)
}()

let HandOpenCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

let HandClosedCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

private func makeCrosshairCursor(size: CGFloat = 20, hotspotAdjustX: CGFloat = 0, hotspotAdjustY: CGFloat = -1) -> NSCursor {
    let imgSize = NSSize(width: size, height: size)
    let centerX = floor(imgSize.width / 2) + 0.5
    let centerY = floor(imgSize.height / 2) + 0.5
    let image = NSImage(size: imgSize)
    image.lockFocus()
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    NSColor.black.setStroke()
    let pathShadow = NSBezierPath()
    pathShadow.lineWidth = 1
    pathShadow.move(to: CGPoint(x: 0, y: centerY))
    pathShadow.line(to: CGPoint(x: imgSize.width, y: centerY))
    pathShadow.move(to: CGPoint(x: centerX, y: 0))
    pathShadow.line(to: CGPoint(x: centerX, y: imgSize.height))
    pathShadow.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSColor.black.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 1
    path.move(to: CGPoint(x: 0, y: centerY))
    path.line(to: CGPoint(x: imgSize.width, y: centerY))
    path.move(to: CGPoint(x: centerX, y: 0))
    path.line(to: CGPoint(x: centerX, y: imgSize.height))
    path.stroke()
    image.unlockFocus()
    let hotspot = CGPoint(x: centerX + hotspotAdjustX, y: centerY + hotspotAdjustY)
    return NSCursor(image: image, hotSpot: hotspot)
}

let CrosshairCursor: NSCursor = makeCrosshairCursor()

struct HashableCGPoint: Hashable, Equatable {
    let point: CGPoint

    init(_ point: CGPoint) {
        self.point = point
    }

    static func == (lhs: HashableCGPoint, rhs: HashableCGPoint) -> Bool {
        return lhs.point.x == rhs.point.x && lhs.point.y == rhs.point.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(point.x)
        hasher.combine(point.y)
    }
}

struct BrushPoint {
    let location: CGPoint
    let pressure: Double

    init(location: CGPoint, pressure: Double = 1.0) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure))
    }
}
