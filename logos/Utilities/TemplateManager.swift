//
//  TemplateManager.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//  Professional Document Template Management System
//

import Foundation
import CoreGraphics

/// PROFESSIONAL TEMPLATE MANAGEMENT SYSTEM
/// Manages document templates and ensures proper new document creation
class TemplateManager {
    
    static let shared = TemplateManager()
    
    private init() {
        loadAvailableTemplates()
    }
    
    // MARK: - Template Types
    
    enum TemplateType: String, CaseIterable {
        case blank = "blank"
        case businessCard = "business_card"
        case letterhead = "letterhead"
        case poster = "poster"
        case logo = "logo"
        case architectural = "architectural"
        case engineering = "engineering"
        case webGraphics = "web_graphics"
        
        var displayName: String {
            switch self {
            case .blank: return "Blank Document"
            case .businessCard: return "Business Card"
            case .letterhead: return "Letterhead"
            case .poster: return "Poster"
            case .logo: return "Logo Design"
            case .architectural: return "Architectural Drawing"
            case .engineering: return "Engineering Drawing"
            case .webGraphics: return "Web Graphics"
            }
        }
        
        var description: String {
            switch self {
            case .blank: return "Empty document with default settings"
            case .businessCard: return "Standard business card (3.5\" × 2\")"
            case .letterhead: return "Letter size with header area (8.5\" × 11\")"
            case .poster: return "Large format poster (24\" × 36\")"
            case .logo: return "Square logo design (500 × 500 px)"
            case .architectural: return "Architectural scale drawing"
            case .engineering: return "Engineering technical drawing"
            case .webGraphics: return "Web-optimized graphics (1920 × 1080 px)"
            }
        }
        
        var iconName: String {
            switch self {
            case .blank: return "doc"
            case .businessCard: return "creditcard"
            case .letterhead: return "doc.text"
            case .poster: return "rectangle"
            case .logo: return "circle.hexagongrid"
            case .architectural: return "building.2"
            case .engineering: return "gearshape.2"
            case .webGraphics: return "display"
            }
        }
    }
    
    // MARK: - Template Configuration
    
    struct TemplateConfiguration {
        let type: TemplateType
        let settings: DocumentSettings
        let initialShapes: [VectorShape]
        let initialLayers: [VectorLayer]
        let metadata: TemplateMetadata
        
        init(type: TemplateType, 
             settings: DocumentSettings, 
             initialShapes: [VectorShape] = [], 
             initialLayers: [VectorLayer] = [],
             metadata: TemplateMetadata = TemplateMetadata()) {
            self.type = type
            self.settings = settings
            self.initialShapes = initialShapes
            self.initialLayers = initialLayers.isEmpty ? [VectorLayer(name: "Layer 1")] : initialLayers
            self.metadata = metadata
        }
    }
    
    struct TemplateMetadata {
        let author: String
        let version: String
        let createdDate: Date
        let description: String
        let tags: [String]
        
        init(author: String = "Logos Vector Graphics",
             version: String = "1.0",
             createdDate: Date = Date(),
             description: String = "",
             tags: [String] = []) {
            self.author = author
            self.version = version
            self.createdDate = createdDate
            self.description = description
            self.tags = tags
        }
    }
    
    // MARK: - Template Storage
    
    private var availableTemplates: [TemplateType: TemplateConfiguration] = [:]
    private var customTemplates: [String: TemplateConfiguration] = [:]
    
    // MARK: - Template Loading
    
    private func loadAvailableTemplates() {
        print("📄 Loading professional document templates...")
        
        // BLANK DOCUMENT (11" × 8.5" Landscape)
        availableTemplates[.blank] = TemplateConfiguration(
            type: .blank,
            settings: DocumentSettings(
                width: 11.0,
                height: 8.5,
                unit: .inches,
                colorMode: .rgb,
                resolution: 72,
                showRulers: true,
                showGrid: false,
                snapToGrid: false,
                gridSpacing: 0.125,
                backgroundColor: VectorColor.white
            ),
            metadata: TemplateMetadata(
                description: "11\" × 8.5\" landscape document with rulers",
                tags: ["blank", "empty", "default", "landscape"]
            )
        )
        
        // BUSINESS CARD (3.5" × 2" with bleed)
        availableTemplates[.businessCard] = TemplateConfiguration(
            type: .businessCard,
            settings: DocumentSettings(
                width: 3.5,  // 3.5 inches
                height: 2.0, // 2 inches
                unit: .inches,
                colorMode: .rgb,
                resolution: 300,    // High resolution for print
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 0.125,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createBusinessCardGuides(),
            metadata: TemplateMetadata(
                description: "Standard business card with safety guides",
                tags: ["business", "card", "print", "standard"]
            )
        )
        
        // LETTERHEAD (8.5" × 11")
        availableTemplates[.letterhead] = TemplateConfiguration(
            type: .letterhead,
            settings: DocumentSettings(
                width: 8.5,  // 8.5 inches
                height: 11.0, // 11 inches
                unit: .inches,
                colorMode: .rgb,
                resolution: 300,
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 0.125,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createLetterheadGuides(),
            metadata: TemplateMetadata(
                description: "Letter size with header and margin guides",
                tags: ["letterhead", "letter", "print", "business"]
            )
        )
        
        // POSTER (24" × 36")
        availableTemplates[.poster] = TemplateConfiguration(
            type: .poster,
            settings: DocumentSettings(
                width: 24.0, // 24 inches
                height: 36.0, // 36 inches
                unit: .inches,
                colorMode: .rgb,
                resolution: 150,    // Large format print
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 1.0,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createPosterGuides(),
            metadata: TemplateMetadata(
                description: "Large format poster with layout guides",
                tags: ["poster", "large", "print", "display"]
            )
        )
        
        // LOGO DESIGN (500 × 500 px)
        availableTemplates[.logo] = TemplateConfiguration(
            type: .logo,
            settings: DocumentSettings(
                width: 500,
                height: 500,
                unit: .pixels,
                colorMode: .rgb,
                resolution: 72,
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 10,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createLogoGuides(),
            metadata: TemplateMetadata(
                description: "Square logo design with center guides",
                tags: ["logo", "design", "square", "branding"]
            )
        )
        
        // ARCHITECTURAL DRAWING
        availableTemplates[.architectural] = TemplateConfiguration(
            type: .architectural,
            settings: DocumentSettings(
                width: 36.0,  // 36 inches (3 feet)
                height: 24.0, // 24 inches (2 feet)
                unit: .inches,
                colorMode: .rgb,
                resolution: 72,
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 1.0,  // 1 inch grid
                backgroundColor: VectorColor.white
            ),
            initialShapes: createArchitecturalGuides(),
            initialLayers: createArchitecturalLayers(),
            metadata: TemplateMetadata(
                description: "Architectural drawing with standard layers",
                tags: ["architectural", "construction", "technical", "CAD"]
            )
        )
        
        // ENGINEERING DRAWING
        availableTemplates[.engineering] = TemplateConfiguration(
            type: .engineering,
            settings: DocumentSettings(
                width: 17.0,  // ANSI C size (17 inches)
                height: 11.0, // 11 inches
                unit: .inches,
                colorMode: .rgb,
                resolution: 72,
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 0.25,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createEngineeringGuides(),
            initialLayers: createEngineeringLayers(),
            metadata: TemplateMetadata(
                description: "Engineering technical drawing with title block",
                tags: ["engineering", "technical", "ANSI", "mechanical"]
            )
        )
        
        // WEB GRAPHICS (1920 × 1080 px)
        availableTemplates[.webGraphics] = TemplateConfiguration(
            type: .webGraphics,
            settings: DocumentSettings(
                width: 1920,
                height: 1080,
                unit: .pixels,
                colorMode: .rgb,
                resolution: 72,
                showRulers: false,
                showGrid: false,
                snapToGrid: false,
                gridSpacing: 8,
                backgroundColor: VectorColor.white
            ),
            initialShapes: createWebGuides(),
            metadata: TemplateMetadata(
                description: "Web graphics optimized for digital display",
                tags: ["web", "digital", "screen", "1080p"]
            )
        )
        
        print("✅ Loaded \(availableTemplates.count) professional templates")
    }
    
    // MARK: - Template Creation Helpers
    
    private func createBusinessCardGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Safety margin (0.125" from edges) - use actual inch measurements since we're using .inches unit
        let margin: CGFloat = 0.125 // 0.125 inches
        var safeArea = VectorShape.rectangle(
            at: CGPoint(x: margin, y: margin),
            size: CGSize(width: 3.5 - (margin * 2), height: 2.0 - (margin * 2))
        )
        safeArea.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 1, alpha: 1)), width: 0.5) // Cyan
        safeArea.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(safeArea)
        
        return guides
    }
    
    private func createLetterheadGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Header area (2" from top)
        var headerArea = VectorShape.rectangle(
            at: CGPoint(x: 1.0, y: 9.0), // 1" margin, 2" from top
            size: CGSize(width: 6.5, height: 1.0) // 6.5" × 1"
        )
        headerArea.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)), width: 0.5) // Blue
        headerArea.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(headerArea)
        
        return guides
    }
    
    private func createPosterGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Title area (top 6")
        var titleArea = VectorShape.rectangle(
            at: CGPoint(x: 2.0, y: 30.0), // 2" margin from left, 6" from bottom
            size: CGSize(width: 20.0, height: 4.0) // 20" × 4"
        )
        titleArea.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1, alpha: 1)), width: 1.0) // Magenta
        titleArea.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(titleArea)
        
        return guides
    }
    
    private func createLogoGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Center cross guides
        var verticalGuide = VectorShape.rectangle(
            at: CGPoint(x: 249, y: 0),
            size: CGSize(width: 2, height: 500)
        )
        verticalGuide.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), width: 0.5) // Red
        verticalGuide.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(verticalGuide)
        
        var horizontalGuide = VectorShape.rectangle(
            at: CGPoint(x: 0, y: 249),
            size: CGSize(width: 500, height: 2)
        )
        horizontalGuide.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), width: 0.5) // Red
        horizontalGuide.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(horizontalGuide)
        
        return guides
    }
    
    private func createArchitecturalGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Drawing border
        var border = VectorShape.rectangle(
            at: CGPoint(x: 2.0, y: 2.0), // 2" margin
            size: CGSize(width: 32.0, height: 20.0) // Drawing area
        )
        border.strokeStyle = StrokeStyle(color: VectorColor.black, width: 2.0)
        border.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(border)
        
        return guides
    }
    
    private func createArchitecturalLayers() -> [VectorLayer] {
        return [
            VectorLayer(name: "A-WALL"),
            VectorLayer(name: "A-DOOR"),
            VectorLayer(name: "A-WIND"),
            VectorLayer(name: "A-DIMS"),
            VectorLayer(name: "A-TEXT"),
            VectorLayer(name: "A-GRID")
        ]
    }
    
    private func createEngineeringGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Title block (bottom right)
        var titleBlock = VectorShape.rectangle(
            at: CGPoint(x: 11.0, y: 1.0), // 6" from left, 1" from bottom
            size: CGSize(width: 6.0, height: 3.0) // 6" × 3"
        )
        titleBlock.strokeStyle = StrokeStyle(color: VectorColor.black, width: 1.0)
        titleBlock.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(titleBlock)
        
        return guides
    }
    
    private func createEngineeringLayers() -> [VectorLayer] {
        return [
            VectorLayer(name: "GEOMETRY"),
            VectorLayer(name: "DIMENSIONS"),
            VectorLayer(name: "CENTERLINES"),
            VectorLayer(name: "HIDDEN"),
            VectorLayer(name: "HATCHING"),
            VectorLayer(name: "TEXT")
        ]
    }
    
    private func createWebGuides() -> [VectorShape] {
        var guides: [VectorShape] = []
        
        // Safe area for web content (avoiding browser chrome)
        var safeArea = VectorShape.rectangle(
            at: CGPoint(x: 64, y: 64),
            size: CGSize(width: 1792, height: 952)
        )
        safeArea.strokeStyle = StrokeStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)), width: 1.0) // Blue
        safeArea.fillStyle = FillStyle(color: VectorColor.clear)
        guides.append(safeArea)
        
        return guides
    }
    
    // MARK: - Public Interface
    
    /// Get all available template types
    func getAvailableTemplates() -> [TemplateType] {
        return TemplateType.allCases
    }
    
    /// Get template configuration for a specific type
    func getTemplate(_ type: TemplateType) -> TemplateConfiguration? {
        return availableTemplates[type]
    }
    
    /// Create a new document from template
    func createDocumentFromTemplate(_ type: TemplateType) -> VectorDocument {
        print("📄 Creating document from template: \(type.displayName)")
        
        guard let template = availableTemplates[type] else {
            print("⚠️ Template not found, using blank template")
            return createBlankDocument()
        }
        
        let document = VectorDocument(settings: template.settings)
        
        // PRESERVE CANVAS LAYER: Don't remove Canvas layer (index 0)
        // Only clear working layers (index 1+) and add template layers
        if document.layers.count > 1 {
            document.layers.removeSubrange(1...)
        }
        
        for layer in template.initialLayers {
            document.layers.append(layer)
        }
        
        // Add template shapes to appropriate layers
        if !template.initialShapes.isEmpty {
            // Add to first working layer (index 1+), not Canvas layer
            let targetLayerIndex = document.layers.count > 1 ? 1 : 0
            if document.layers.count <= targetLayerIndex {
                document.layers.append(VectorLayer(name: "Layer 1"))
            }
            
            for shape in template.initialShapes {
                document.layers[targetLayerIndex].shapes.append(shape)
            }
        }
        
        // Ensure we have at least one working layer
        if document.layers.count < 2 {
            document.layers.append(VectorLayer(name: "Layer 1"))
        }
        
        // Select the first working layer (not Canvas layer)
        document.selectedLayerIndex = 1
        
        print("✅ Created document from template: \(type.displayName)")
        print("📊 Document: \(document.layers.count) layers, \(document.getTotalShapeCount()) shapes")
        
        return document
    }
    
    /// Create a truly blank document (no content whatsoever)
    func createBlankDocument() -> VectorDocument {
        print("📄 Creating truly blank document...")
        
        let blankSettings = DocumentSettings(
            width: 11.0,
            height: 8.5,
            unit: .inches,
            colorMode: .rgb,
            resolution: 72,
            showRulers: true,
            showGrid: false,
            snapToGrid: false,
            gridSpacing: 0.125,
            backgroundColor: VectorColor.white
        )
        
        let document = VectorDocument(settings: blankSettings)
        
        // PRESERVE CANVAS LAYER: Don't remove Canvas layer (index 0)
        // Only clear working layers (index 1+)
        if document.layers.count > 1 {
            document.layers.removeSubrange(1...)
        }
        
        // Ensure we have a working layer
        if document.layers.count < 2 {
            document.layers.append(VectorLayer(name: "Layer 1"))
        }
        
        // Select the working layer (not the Canvas layer)
        document.selectedLayerIndex = 1
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        document.textObjects.removeAll()
        
        print("✅ Created truly blank document - Canvas layer preserved!")
        return document
    }
    
    /// Save custom template
    func saveCustomTemplate(name: String, document: VectorDocument, description: String = "") {
        let metadata = TemplateMetadata(
            description: description,
            tags: ["custom", "user"]
        )
        
        let configuration = TemplateConfiguration(
            type: .blank, // Custom templates use blank type
            settings: document.settings,
            initialShapes: document.getAllShapes(),
            initialLayers: document.layers,
            metadata: metadata
        )
        
        customTemplates[name] = configuration
        print("✅ Saved custom template: \(name)")
    }
    
    /// Get all custom template names
    func getCustomTemplateNames() -> [String] {
        return Array(customTemplates.keys).sorted()
    }
    
    /// Create document from custom template
    func createDocumentFromCustomTemplate(name: String) -> VectorDocument? {
        guard let template = customTemplates[name] else {
            print("❌ Custom template not found: \(name)")
            return nil
        }
        
        let document = VectorDocument(settings: template.settings)
        document.layers = template.initialLayers
        
        print("✅ Created document from custom template: \(name)")
        return document
    }
    
    /// Get current template being used (for debugging)
    func getCurrentTemplateInfo(for document: VectorDocument) -> String {
        // Analyze document to determine likely template source
        let shapeCount = document.getTotalShapeCount()
        let layerCount = document.layers.count
        let settings = document.settings
        
        if shapeCount == 0 && layerCount == 1 && document.layers[0].shapes.isEmpty {
            return "Template: Blank Document (truly empty)"
        }
        
        // Check against known templates
        for (type, template) in availableTemplates {
            if settings.width == template.settings.width &&
               settings.height == template.settings.height &&
               settings.unit == template.settings.unit {
                return "Template: \(type.displayName) (\(template.metadata.description))"
            }
        }
        
        return "Template: Custom or Modified (\(shapeCount) shapes, \(layerCount) layers)"
    }
}

// MARK: - Template Extensions

extension VectorDocument {
    
    /// Get all shapes from all layers
    func getAllShapes() -> [VectorShape] {
        var allShapes: [VectorShape] = []
        for layer in layers {
            allShapes.append(contentsOf: layer.shapes)
        }
        return allShapes
    }
    
    /// Get total shape count across all layers
    func getTotalShapeCount() -> Int {
        return layers.reduce(0) { $0 + $1.shapes.count }
    }
}

extension DocumentSettings {
    
    /// Create settings with professional defaults
    static func professional(width: CGFloat, height: CGFloat, unit: MeasurementUnit, dpi: Double = 72) -> DocumentSettings {
        return DocumentSettings(
            width: width,
            height: height,
            unit: unit,
            colorMode: .rgb,
            resolution: dpi,
            showRulers: true,
            showGrid: false,
            snapToGrid: true,
            gridSpacing: unit == .pixels ? 10 : 0.125,
            backgroundColor: VectorColor.white
        )
    }
} 