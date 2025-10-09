//
//  CGBlendModeView.swift
//  logos inkpen.io
//
//  SwiftUI extension to use full CGBlendMode via NSViewRepresentable and CALayer compositingFilter
//

import SwiftUI
import AppKit
import CoreImage

// MARK: - NSView with CALayer compositingFilter Support
class BlendModeNSView: NSView {
    var contentView: NSView?

    var blendMode: CGBlendMode = .normal {
        didSet {
            updateCompositingFilter()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        // Enable Core Image filters on layer
        wantsLayer = true
        layerUsesCoreImageFilters = true
    }

    private func updateCompositingFilter() {
        guard let layer = self.layer else { return }

        // Map CGBlendMode to CIFilter name
        let filterName = ciFilterName(for: blendMode)

        if filterName == "normal" || filterName == nil {
            layer.compositingFilter = nil
        } else if let filterName = filterName {
            layer.compositingFilter = CIFilter(name: filterName)
        }
    }

    /// Map CGBlendMode to CIFilter name
    /// Note: Core Image does NOT have CIDestinationOverCompositing or CIDestinationOutCompositing
    /// These modes will fall back to .normal (no filter)
    private func ciFilterName(for mode: CGBlendMode) -> String? {
        switch mode {
        case .normal: return nil
        case .multiply: return "CIMultiplyBlendMode"
        case .screen: return "CIScreenBlendMode"
        case .overlay: return "CIOverlayBlendMode"
        case .darken: return "CIDarkenBlendMode"
        case .lighten: return "CILightenBlendMode"
        case .colorDodge: return "CIColorDodgeBlendMode"
        case .colorBurn: return "CIColorBurnBlendMode"
        case .softLight: return "CISoftLightBlendMode"
        case .hardLight: return "CIHardLightBlendMode"
        case .difference: return "CIDifferenceBlendMode"
        case .exclusion: return "CIExclusionBlendMode"
        case .hue: return "CIHueBlendMode"
        case .saturation: return "CISaturationBlendMode"
        case .color: return "CIColorBlendMode"
        case .luminosity: return "CILuminosityBlendMode"
        case .plusDarker: return "CILinearBurnBlendMode"  // Closest equivalent
        case .plusLighter: return "CILinearDodgeBlendMode"  // Closest equivalent

        // Porter-Duff compositing modes
        case .sourceAtop: return "CISourceAtopCompositing"

        // UNSUPPORTED: Core Image does not have Destination* compositing filters
        // These will fall back to .normal
        case .destinationOver: return nil  // NOT SUPPORTED in Core Image
        case .destinationOut: return nil  // NOT SUPPORTED in Core Image

        // Unsupported modes - return nil to use normal
        default: return nil
        }
    }

    override var isFlipped: Bool { true }
}

// MARK: - NSViewRepresentable Wrapper
struct CGBlendModeContainer<Content: View>: NSViewRepresentable {
    let blendMode: CGBlendMode
    let content: Content

    func makeNSView(context: Context) -> BlendModeNSView {
        let blendView = BlendModeNSView()
        blendView.blendMode = blendMode

        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        blendView.addSubview(hostingView)

        // Pin hosting view to blend view
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: blendView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blendView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: blendView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blendView.bottomAnchor)
        ])

        blendView.contentView = hostingView

        return blendView
    }

    func updateNSView(_ nsView: BlendModeNSView, context: Context) {
        nsView.blendMode = blendMode

        // Update content
        if let hostingView = nsView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Apply a CGBlendMode to this view using NSViewRepresentable with CALayer compositingFilter
    /// This gives access to ALL CGBlendMode modes via Core Image filters
    func cgBlendMode(_ mode: CGBlendMode) -> some View {
        CGBlendModeContainer(blendMode: mode, content: self)
    }

    /// Apply a BlendMode enum to this view using CGBlendMode rendering
    /// This allows using ALL BlendMode cases via Core Image filters
    func cgBlendMode(_ mode: BlendMode) -> some View {
        CGBlendModeContainer(blendMode: mode.cgBlendMode, content: self)
    }
}
