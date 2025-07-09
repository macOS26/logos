//
//  logosApp.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

@main
struct logosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // PROFESSIONAL MENU BAR (Adobe Illustrator/FreeHand/CorelDRAW Standards)
            // Order: File (System), Edit (System), Object, Select, View, Window, Help (System)
            
            // Add essential tool commands to Edit menu (professional standard)
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Group {
                    Text("Tools")
                        .font(.headline)
                        .disabled(true)
                    
                    Button("Selection Tool") {
                        NotificationCenter.default.post(name: .switchTool, object: DrawingTool.selection)
                    }
                    .keyboardShortcut("v")
                    
                    Button("Direct Selection Tool") {
                        NotificationCenter.default.post(name: .switchTool, object: DrawingTool.directSelection)
                    }
                    .keyboardShortcut("a")
                    
                    Button("Pen Tool") {
                        NotificationCenter.default.post(name: .switchTool, object: DrawingTool.bezierPen)
                    }
                    .keyboardShortcut("p")
                    
                    Button("Text Tool") {
                        NotificationCenter.default.post(name: .switchTool, object: DrawingTool.text)
                    }
                    .keyboardShortcut("t")
                    
                    Button("Hand Tool") {
                        NotificationCenter.default.post(name: .switchTool, object: DrawingTool.hand)
                    }
                    .keyboardShortcut("h")
                }
            }
            
            // Professional menu order: Object, Select, View, Window
            ObjectMenuCommands()
            SelectMenuCommands()
            ViewMenuCommands()
            WindowMenuCommands()
        }
    }
}

// MARK: - Professional Object Menu (Adobe Illustrator Style)
struct ObjectMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Object") {
            Group {
                Text("Arrange")
                    .font(.headline)
                    .disabled(true)
                
                Button("Bring to Front") {
                    NotificationCenter.default.post(name: .bringToFront, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                
                Button("Bring Forward") {
                    NotificationCenter.default.post(name: .bringForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command])
                
                Button("Send Backward") {
                    NotificationCenter.default.post(name: .sendBackward, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command])
                
                Button("Send to Back") {
                    NotificationCenter.default.post(name: .sendToBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            }
            
            Divider()
            
            Group {
                Text("Group")
                    .font(.headline)
                    .disabled(true)
                
                Button("Group") {
                    NotificationCenter.default.post(name: .groupObjects, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command])
                
                Button("Ungroup") {
                    NotificationCenter.default.post(name: .ungroupObjects, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            
            Divider()
            
            Group {
                Text("Lock")
                    .font(.headline)
                    .disabled(true)
                
                Button("Lock") {
                    NotificationCenter.default.post(name: .lockObjects, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command])
                
                Button("Unlock All") {
                    NotificationCenter.default.post(name: .unlockAll, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
            }
            
            Divider()
            
            Group {
                Text("Hide")
                    .font(.headline)
                    .disabled(true)
                
                Button("Hide") {
                    NotificationCenter.default.post(name: .hideObjects, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command])
                
                Button("Show All") {
                    NotificationCenter.default.post(name: .showAll, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
            }
            
            Divider()
            
            Group {
                Text("Path")
                    .font(.headline)
                    .disabled(true)
                
                Button("Close Path") {
                    NotificationCenter.default.post(name: .closePath, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
                
                Button("Join") {
                    NotificationCenter.default.post(name: .joinPaths, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command])
            }
            
            Divider()
            
            Group {
                Text("Text")
                    .font(.headline)
                    .disabled(true)
                
                Button("Create Outlines") {
                    NotificationCenter.default.post(name: .createOutlines, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Professional Select Menu (Adobe Illustrator Style)
struct SelectMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Select") {
            Button("All") {
                NotificationCenter.default.post(name: .selectAll, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
            
            Button("Deselect") {
                NotificationCenter.default.post(name: .deselectAll, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Inverse") {
                NotificationCenter.default.post(name: .selectInverse, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            
            Divider()
            
            Group {
                Text("Same")
                    .font(.headline)
                    .disabled(true)
                
                Button("Same Fill Color") {
                    NotificationCenter.default.post(name: .selectSameFill, object: nil)
                }
                
                Button("Same Stroke Color") {
                    NotificationCenter.default.post(name: .selectSameStroke, object: nil)
                }
                
                Button("Same Stroke Weight") {
                    NotificationCenter.default.post(name: .selectSameStrokeWeight, object: nil)
                }
            }
        }
    }
}

// MARK: - Professional View Menu (Adobe Illustrator Style)
struct ViewMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("View") {
            Group {
                Text("Zoom")
                    .font(.headline)
                    .disabled(true)
                
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("=", modifiers: [.command])
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: [.command])
                
                Button("Fit to Page") {
                    NotificationCenter.default.post(name: .fitToPage, object: nil)
                }
                .keyboardShortcut("0", modifiers: [.command])
                
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .actualSize, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])
            }
            
            Divider()
            
            Group {
                Text("View Mode")
                    .font(.headline)
                    .disabled(true)
                
                Button("Color View") {
                    NotificationCenter.default.post(name: .colorView, object: nil)
                }
                .keyboardShortcut("y", modifiers: [.command])
                
                Button("Keyline View") {
                    NotificationCenter.default.post(name: .keylineView, object: nil)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])
            }
            
            Divider()
            
            Group {
                Text("Show/Hide")
                    .font(.headline)
                    .disabled(true)
                
                Button("Show/Hide Rulers") {
                    NotificationCenter.default.post(name: .toggleRulers, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("Show/Hide Grid") {
                    NotificationCenter.default.post(name: .toggleGrid, object: nil)
                }
                .keyboardShortcut("'", modifiers: [.command])
                
                Button("Snap to Grid") {
                    NotificationCenter.default.post(name: .toggleSnapToGrid, object: nil)
                }
                .keyboardShortcut("'", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Professional Window Menu (Adobe Illustrator Style)
struct WindowMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Window") {
            Text("Panels")
                .font(.headline)
                .disabled(true)
            
            Button("Layers") {
                NotificationCenter.default.post(name: .showLayersPanel, object: nil)
            }
            // Note: F7 shortcut - handled via system
            
            Button("Color") {
                NotificationCenter.default.post(name: .showColorPanel, object: nil)
            }
            // Note: F6 shortcut - handled via system
            
            Button("Stroke/Fill") {
                NotificationCenter.default.post(name: .showStrokeFillPanel, object: nil)
            }
            // Note: F10 shortcut - handled via system
            
            Button("Typography") {
                NotificationCenter.default.post(name: .showTypographyPanel, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            
            Button("Path Operations") {
                NotificationCenter.default.post(name: .showPathOpsPanel, object: nil)
            }
            // Note: F9 shortcut - handled via system
            
            Divider()
            
            Text("Tool Palettes")
                .font(.headline)
                .disabled(true)
            
            Button("Tools") {
                NotificationCenter.default.post(name: .showToolsPanel, object: nil)
            }
            // Note: F1 shortcut - handled via system
        }
    }
}

// MARK: - Notification Names for Menu Commands
extension Notification.Name {
    // Tool Commands
    static let switchTool = Notification.Name("switchTool")
    
    // Selection Commands
    static let selectAll = Notification.Name("selectAll")
    static let deselectAll = Notification.Name("deselectAll")
    static let selectInverse = Notification.Name("selectInverse")
    static let selectSameFill = Notification.Name("selectSameFill")
    static let selectSameStroke = Notification.Name("selectSameStroke")
    static let selectSameStrokeWeight = Notification.Name("selectSameStrokeWeight")
    
    // Object Commands
    static let bringToFront = Notification.Name("bringToFront")
    static let bringForward = Notification.Name("bringForward")
    static let sendBackward = Notification.Name("sendBackward")
    static let sendToBack = Notification.Name("sendToBack")
    static let groupObjects = Notification.Name("groupObjects")
    static let ungroupObjects = Notification.Name("ungroupObjects")
    static let lockObjects = Notification.Name("lockObjects")
    static let unlockAll = Notification.Name("unlockAll")
    static let hideObjects = Notification.Name("hideObjects")
    static let showAll = Notification.Name("showAll")
    static let closePath = Notification.Name("closePath")
    static let joinPaths = Notification.Name("joinPaths")
    static let createOutlines = Notification.Name("createOutlines")
    
    // View Commands
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let fitToPage = Notification.Name("fitToPage")
    static let actualSize = Notification.Name("actualSize")
    static let colorView = Notification.Name("colorView")
    static let keylineView = Notification.Name("keylineView")
    static let toggleRulers = Notification.Name("toggleRulers")
    static let toggleGrid = Notification.Name("toggleGrid")
    static let toggleSnapToGrid = Notification.Name("toggleSnapToGrid")
    
    // Window Commands
    static let showLayersPanel = Notification.Name("showLayersPanel")
    static let showColorPanel = Notification.Name("showColorPanel")
    static let showStrokeFillPanel = Notification.Name("showStrokeFillPanel")
    static let showTypographyPanel = Notification.Name("showTypographyPanel")
    static let showPathOpsPanel = Notification.Name("showPathOpsPanel")
    static let showToolsPanel = Notification.Name("showToolsPanel")
    static let switchToPanel = Notification.Name("switchToPanel")
}
