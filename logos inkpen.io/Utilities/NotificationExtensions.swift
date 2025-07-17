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
    
    // MARK: - Selection Commands
    static let selectAll = Notification.Name("SelectAll")
    static let deselectAll = Notification.Name("DeselectAll")
    
    // MARK: - Object Commands - Arrange
    static let bringToFront = Notification.Name("BringToFront")
    static let bringForward = Notification.Name("BringForward")
    static let sendBackward = Notification.Name("SendBackward")
    static let sendToBack = Notification.Name("SendToBack")
    
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
    
    // MARK: - Panel Commands
    static let showLayersPanel = Notification.Name("ShowLayersPanel")
    static let showColorPanel = Notification.Name("ShowColorPanel")
    static let showStrokeFillPanel = Notification.Name("ShowStrokeFillPanel")
    static let showTypographyPanel = Notification.Name("ShowTypographyPanel")
    static let showPathOpsPanel = Notification.Name("ShowPathOpsPanel")
    static let switchToPanel = Notification.Name("SwitchToPanel")
    
    // MARK: - Development Commands - CoreGraphics Path Operations Testing
    static let showCoreGraphicsTest = Notification.Name("ShowCoreGraphicsTest")
    static let runPathOperationsBenchmark = Notification.Name("RunPathOperationsBenchmark")
} 