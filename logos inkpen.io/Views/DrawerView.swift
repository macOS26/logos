////
////  DrawerView.swift
////  logos inkpen.io
////
////  Created by AI Assistant
////
//
//import SwiftUI
//
//// MARK: - Drawer Direction
//enum DrawerDirection {
//    case left, right, top, bottom
//}
//
//// MARK: - Drawer View
//struct DrawerView<Content: View>: View {
//    let content: Content
//    let direction: DrawerDirection
//    let size: CGFloat
//    @Binding var isOpen: Bool
//    
//    let animationDuration: Double = 0.3
//    
//    init(
//        direction: DrawerDirection,
//        size: CGFloat,
//        isOpen: Binding<Bool>,
//        @ViewBuilder content: () -> Content
//    ) {
//        self.direction = direction
//        self.size = size
//        self._isOpen = isOpen
//        self.content = content()
//    }
//    
//    var body: some View {
//        ZStack {
//            // Background overlay when drawer is open
//            if isOpen {
//                Color.black.opacity(0.3)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        withAnimation(.easeInOut(duration: animationDuration)) {
//                            isOpen = false
//                        }
//                    }
//                    .transition(.opacity)
//            }
//            
//            // Drawer content
//            VStack {
//                if direction == .bottom {
//                    Spacer()
//                }
//                
//                HStack {
//                    if direction == .right {
//                        Spacer()
//                    }
//                    
//                    // Drawer panel
//                    drawerPanel
//                    
//                    if direction == .left {
//                        Spacer()
//                    }
//                }
//                
//                if direction == .top {
//                    Spacer()
//                }
//            }
//        }
//    }
//    
//    private var drawerPanel: some View {
//        VStack(spacing: 0) {
//            // Drawer handle (for visual feedback)
//            drawerHandle
//                .padding(.top, direction == .bottom ? 8 : 0)
//                .padding(.bottom, direction == .top ? 8 : 0)
//            
//            // Drawer content
//            content
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//        .background(Color(NSColor.controlBackgroundColor))
//        .overlay(
//            Rectangle()
//                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//        )
//        .cornerRadius(direction == .bottom || direction == .top ? 12 : 0)
//        .shadow(radius: 8)
//        .frame(
//            width: direction == .left || direction == .right ? size : nil,
//            height: direction == .top || direction == .bottom ? size : nil
//        )
//        .offset(
//            x: offsetX,
//            y: offsetY
//        )
//        .transition(drawerTransition)
//    }
//    
//    private var drawerHandle: some View {
//        RoundedRectangle(cornerRadius: 3)
//            .fill(Color.gray.opacity(0.5))
//            .frame(
//                width: direction == .left || direction == .right ? 4 : 40,
//                height: direction == .left || direction == .right ? 40 : 4
//            )
//    }
//    
//    private var offsetX: CGFloat {
//        guard !isOpen else { return 0 }
//        
//        switch direction {
//        case .left:
//            return -size
//        case .right:
//            return size
//        default:
//            return 0
//        }
//    }
//    
//    private var offsetY: CGFloat {
//        guard !isOpen else { return 0 }
//        
//        switch direction {
//        case .top:
//            return -size
//        case .bottom:
//            return size
//        default:
//            return 0
//        }
//    }
//    
//    private var drawerTransition: AnyTransition {
//        switch direction {
//        case .left:
//            return .move(edge: .leading)
//        case .right:
//            return .move(edge: .trailing)
//        case .top:
//            return .move(edge: .top)
//        case .bottom:
//            return .move(edge: .bottom)
//        }
//    }
//}
//
//// MARK: - Drawer Toggle Button
//struct DrawerToggleButton: View {
//    let icon: String
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            Image(systemName: icon)
//                .font(.system(size: 16, weight: .medium))
//                .foregroundColor(.primary)
//                .frame(width: 32, height: 32)
//                .background(Color(NSColor.controlBackgroundColor))
//                .cornerRadius(6)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 6)
//                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//                )
//        }
//        .buttonStyle(PlainButtonStyle())
//        .help("Toggle Drawer")
//    }
//}
//
//// MARK: - Preview
//struct DrawerView_Previews: PreviewProvider {
//    static var previews: some View {
//        DrawerViewPreview()
//    }
//}
//
//struct DrawerViewPreview: View {
//    @State private var isLeftDrawerOpen = false
//    @State private var isBottomDrawerOpen = false
//    
//    var body: some View {
//        ZStack {
//            // Main content
//            VStack {
//                Text("Main App Content")
//                    .font(.title)
//                    .foregroundColor(.primary)
//                
//                HStack {
//                    DrawerToggleButton(icon: "sidebar.left") {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isLeftDrawerOpen.toggle()
//                        }
//                    }
//                    
//                    DrawerToggleButton(icon: "rectangle.bottomhalf.inset.filled") {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isBottomDrawerOpen.toggle()
//                        }
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Color.gray.opacity(0.1))
//            
//            // Left drawer
//            DrawerView(direction: .left, size: 300, isOpen: $isLeftDrawerOpen) {
//                VStack(alignment: .leading, spacing: 16) {
//                    Text("Left Drawer")
//                        .font(.headline)
//                    
//                    Text("This is a left sliding drawer!")
//                    
//                    Button("Close") {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isLeftDrawerOpen = false
//                        }
//                    }
//                    .buttonStyle(.borderedProminent)
//                    
//                    Spacer()
//                }
//                .padding()
//            }
//            
//            // Bottom drawer
//            DrawerView(direction: .bottom, size: 200, isOpen: $isBottomDrawerOpen) {
//                VStack(spacing: 16) {
//                    Text("Bottom Drawer")
//                        .font(.headline)
//                    
//                    Text("This is a bottom sliding drawer!")
//                    
//                    Button("Close") {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isBottomDrawerOpen = false
//                        }
//                    }
//                    .buttonStyle(.borderedProminent)
//                    
//                    Spacer()
//                }
//                .padding()
//            }
//        }
//        .frame(width: 800, height: 600)
//    }
//}
