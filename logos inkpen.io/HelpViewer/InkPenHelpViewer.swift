import SwiftUI
import WebKit

struct InkPenHelpViewer: View {
    @State private var currentPage = "index"
    @State private var navigationStack: [String] = []
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HelpToolbar(
                currentPage: $currentPage,
                navigationStack: $navigationStack,
                searchText: $searchText,
                dismiss: dismiss
            )
            
            Divider()
            
            HelpWebView(
                currentPage: $currentPage,
                navigationStack: $navigationStack
            )
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct HelpToolbar: View {
    @Binding var currentPage: String
    @Binding var navigationStack: [String]
    @Binding var searchText: String
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Button(action: navigateBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(navigationStack.isEmpty)
            
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(false)
            
            Button(action: navigateHome) {
                Image(systemName: "house")
            }
            
            Spacer()
            
            TextField("Search Help", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 200)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
        }
        .padding()
    }
    
    func navigateBack() {
        if !navigationStack.isEmpty {
            currentPage = navigationStack.removeLast()
        }
    }
    
    func navigateForward() {
    }
    
    func navigateHome() {
        navigationStack.append(currentPage)
        currentPage = "index"
    }
}

struct HelpWebView: NSViewRepresentable {
    @Binding var currentPage: String
    @Binding var navigationStack: [String]
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        loadPage(webView: webView, page: currentPage)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadPage(webView: webView, page: currentPage)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadPage(webView: WKWebView, page: String) {
        let helpPath = Bundle.main.path(forResource: "LogosInkPenHelp", ofType: "help")
        guard let helpPath = helpPath else { return }
        
        let resourcesPath = (helpPath as NSString).appendingPathComponent("Contents/Resources/en.lproj")
        let htmlPath = (resourcesPath as NSString).appendingPathComponent("\(page).html")
        
        if FileManager.default.fileExists(atPath: htmlPath) {
            let url = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: resourcesPath))
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HelpWebView
        
        init(_ parent: HelpWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    let fileName = url.deletingPathExtension().lastPathComponent
                    
                    parent.navigationStack.append(parent.currentPage)
                    parent.currentPage = fileName
                    
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

class InkPenHelpWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Logos InkPen Help"
        window.center()
        
        let helpViewer = InkPenHelpViewer()
        window.contentView = NSHostingView(rootView: helpViewer)
        
        self.init(window: window)
    }
    
    static func showHelp() {
        let helpWindow = InkPenHelpWindowController()
        helpWindow.showWindow(nil)
    }
}