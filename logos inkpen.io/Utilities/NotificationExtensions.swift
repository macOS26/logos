//
//  NotificationExtensions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/5/25.
//

import Foundation

extension Notification.Name {
    // MARK: - Tool Commands
    static let switchTool = Notification.Name("SwitchTool")
    
    // MARK: - Selection Commands (REMOVED - using DocumentState methods directly)
    
    // MARK: - Object Commands - Arrange (REMOVED - using DocumentState methods directly)
    
    // MARK: - Object Commands - Lock/Hide
    static let lockObjects = Notification.Name("LockObjects")
    static let unlockAll = Notification.Name("UnlockAll")
    static let hideObjects = Notification.Name("HideObjects")
    static let showAll = Notification.Name("ShowAll")
    
    // MARK: - View Commands - Zoom
    static let zoomIn = Notification.Name("ZoomIn")
    static let zoomOut = Notification.Name("ZoomOut")
    static let fitToPage = Notification.Name("FitToPage")
    static let actualSize = Notification.Name("ActualSize")
    
    // MARK: - View Commands - View Mode
    static let colorView = Notification.Name("ColorView")
    static let keylineView = Notification.Name("KeylineView")
    
    // MARK: - View Commands - Show/Hide
    static let toggleRulers = Notification.Name("ToggleRulers")
    static let toggleGrid = Notification.Name("ToggleGrid")
    static let toggleSnapToGrid = Notification.Name("ToggleSnapToGrid")
    
    // MARK: - Text Commands
    static let createOutlines = Notification.Name("CreateOutlines")
    
    // MARK: - Path Cleanup Commands (Professional Tools)
    static let cleanupDuplicatePoints = Notification.Name("cleanupDuplicatePoints")
    static let cleanupAllDuplicatePoints = Notification.Name("cleanupAllDuplicatePoints")
    static let testDuplicatePointMerger = Notification.Name("testDuplicatePointMerger")
    
    // MARK: - Panel Commands (REMOVED - using AppState with @Observable instead)
    
    // MARK: - Development Commands - CoreGraphics Path Operations Testing
    static let showCoreGraphicsTest = Notification.Name("ShowCoreGraphicsTest")
    static let runPathOperationsBenchmark = Notification.Name("RunPathOperationsBenchmark")
} 