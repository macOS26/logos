//
//  TemplateManager.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//  Professional Document Template Management System
//

import SwiftUI

/// PROFESSIONAL TEMPLATE MANAGEMENT SYSTEM
/// Manages document templates and ensures proper new document creation
class TemplateManager {
    
    static let shared = TemplateManager()
    private var isInitialized = false
    
    private init() {
        // Initialize templates synchronously - they're fast to load
        Log.info("📄 Starting template initialization...", category: .general)
        loadAvailableTemplates()
        isInitialized = true
        Log.info("✅ Template initialization completed", category: .fileOperations)
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
    }
    
    // MARK: - Template Configuration
    
    struct TemplateConfiguration {
        let settings: DocumentSettings

        init(settings: DocumentSettings) {
            self.settings = settings
        }
    }
    
    // MARK: - Template Storage
    
    private var availableTemplates: [TemplateType: TemplateConfiguration] = [:]
    
    // MARK: - Template Loading
    
    private func loadAvailableTemplates() {
        Log.info("📄 Loading professional document templates...", category: .general)
        
        // BLANK DOCUMENT (11" × 8.5" Landscape)
        availableTemplates[.blank] = TemplateConfiguration(
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
            )
        )
        
        // BUSINESS CARD (3.5" × 2" with bleed)
        availableTemplates[.businessCard] = TemplateConfiguration(
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
            )
        )
        
        // LETTERHEAD (8.5" × 11")
        availableTemplates[.letterhead] = TemplateConfiguration(
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
            )
        )
        
        // POSTER (24" × 36")
        availableTemplates[.poster] = TemplateConfiguration(
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
            )
        )
        
        // LOGO DESIGN (500 × 500 px)
        availableTemplates[.logo] = TemplateConfiguration(
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
            )
        )
        
        // ARCHITECTURAL (36" × 24")
        availableTemplates[.architectural] = TemplateConfiguration(
            settings: DocumentSettings(
                width: 36.0, // 36 inches
                height: 24.0, // 24 inches
                unit: .inches,
                colorMode: .cmyk,
                resolution: 150,
                showRulers: true,
                showGrid: true,
                snapToGrid: true,
                gridSpacing: 1.0,
                backgroundColor: VectorColor.white
            )
        )
        
        // ENGINEERING (11" × 8.5")
        availableTemplates[.engineering] = TemplateConfiguration(
            settings: DocumentSettings(
                width: 11.0, // 11 inches
                height: 8.5, // 8.5 inches
                unit: .inches,
                colorMode: .cmyk,
                resolution: 300,
                showRulers: true,
                showGrid: true,
                snapToGrid: true,
                gridSpacing: 0.125,
                backgroundColor: VectorColor.white
            )
        )
        
        // WEB GRAPHICS (1920 × 1080 px)
        availableTemplates[.webGraphics] = TemplateConfiguration(
            settings: DocumentSettings(
                width: 1920,
                height: 1080,
                unit: .pixels,
                colorMode: .rgb,
                resolution: 72,
                showRulers: true,
                showGrid: false,
                snapToGrid: true,
                gridSpacing: 20,
                backgroundColor: VectorColor.white
            )
        )
        
        Log.info("✅ Loaded \(availableTemplates.count) professional templates", category: .fileOperations)
    }
    // MARK: - Public Interface
    
    /// Create a truly blank document (no content whatsoever)
    func createBlankDocument(with defaultTool: DrawingTool = .selection) -> VectorDocument {
        Log.info("📄 Creating truly blank document...", category: .general)
        
        // Create document immediately without waiting for template initialization
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
        
        // VectorDocument.init() now creates Canvas (index 0) + Layer 1 (index 1)
        // Select the working layer (not the Canvas)
        document.selectedLayerIndex = 2  // Index 2 since Canvas is at index 0 and Pasteboard is at index 1
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        document.removeAllText()  // Use unified system method
        
        // Apply the default tool setting
        document.currentTool = defaultTool
        Log.info("🛠️ Set default tool to: \(defaultTool.rawValue)", category: .general)
        
        Log.info("✅ Created truly blank document - single layer!", category: .fileOperations)
        return document
    }
}
