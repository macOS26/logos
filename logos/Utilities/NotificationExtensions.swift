//
//  NotificationExtensions.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation

extension NSNotification.Name {
    // MARK: - Tool Commands
    static let switchTool = NSNotification.Name("SwitchTool")
    
    // MARK: - Selection Commands
    static let selectAll = NSNotification.Name("SelectAll")
    static let deselectAll = NSNotification.Name("DeselectAll")
    
    // MARK: - Object Commands - Arrange
    static let bringToFront = NSNotification.Name("BringToFront")
    static let bringForward = NSNotification.Name("BringForward")
    static let sendBackward = NSNotification.Name("SendBackward")
    static let sendToBack = NSNotification.Name("SendToBack")
    
    // MARK: - Object Commands - Lock/Hide
    static let lockObjects = NSNotification.Name("LockObjects")
    static let unlockAll = NSNotification.Name("UnlockAll")
    static let hideObjects = NSNotification.Name("HideObjects")
    static let showAll = NSNotification.Name("ShowAll")
    
    // MARK: - View Commands - Zoom
    static let zoomIn = NSNotification.Name("ZoomIn")
    static let zoomOut = NSNotification.Name("ZoomOut")
    static let fitToPage = NSNotification.Name("FitToPage")
    static let actualSize = NSNotification.Name("ActualSize")
    
    // MARK: - View Commands - View Mode
    static let colorView = NSNotification.Name("ColorView")
    static let keylineView = NSNotification.Name("KeylineView")
    
    // MARK: - View Commands - Show/Hide
    static let toggleRulers = NSNotification.Name("ToggleRulers")
    static let toggleGrid = NSNotification.Name("ToggleGrid")
    static let toggleSnapToGrid = NSNotification.Name("ToggleSnapToGrid")
    
    // MARK: - Text Commands
    static let createOutlines = NSNotification.Name("CreateOutlines")
    
    // MARK: - Panel Commands
    static let showLayersPanel = NSNotification.Name("ShowLayersPanel")
    static let showColorPanel = NSNotification.Name("ShowColorPanel")
    static let showStrokeFillPanel = NSNotification.Name("ShowStrokeFillPanel")
    static let showTypographyPanel = NSNotification.Name("ShowTypographyPanel")
    static let showPathOpsPanel = NSNotification.Name("ShowPathOpsPanel")
    static let switchToPanel = NSNotification.Name("SwitchToPanel")
} 