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
    
    // MARK: - Template Loading
    
    private func loadAvailableTemplates() {
        // Template loading removed - functionality was not being used
        Log.info("📄 Template system initialized", category: .general)
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
