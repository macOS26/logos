import SwiftUI
import WebKit
import Combine

class InternalHelpViewer: NSObject {
    static let shared = InternalHelpViewer()
    private var helpWindow: NSWindow?
    
    func showHelp() {
        if let window = helpWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Logos InkPen Help"
        window.center()
        window.setFrameAutosaveName("InkPenHelpWindow")
        
        let contentView = InternalHelpContentView()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        helpWindow = window
    }
}

struct InternalHelpContentView: View {
    @StateObject private var navigator = HelpNavigator()
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            HelpNavigationBar(
                navigator: navigator,
                searchText: $searchText
            )
            
            Divider()
            
            InternalHelpWebView(
                navigator: navigator,
                colorScheme: colorScheme
            )
        }
    }
}

struct HelpNavigationBar: View {
    @ObservedObject var navigator: HelpNavigator
    @Binding var searchText: String
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: navigator.goBack) {
                Image(systemName: "chevron.backward")
                    .imageScale(.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!navigator.canGoBack)
            .help("Go Back")
            
            Button(action: navigator.goForward) {
                Image(systemName: "chevron.forward")
                    .imageScale(.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!navigator.canGoForward)
            .help("Go Forward")
            
            Button(action: navigator.goHome) {
                Image(systemName: "house")
                    .imageScale(.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Home")
            
            Divider()
                .frame(height: 20)
            
            Text(navigator.currentTitle)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search Help", text: $searchText, onCommit: performSearch)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 200)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(12)
    }
    
    func performSearch() {
        if !searchText.isEmpty {
            navigator.search(searchText)
        }
    }
}

class HelpNavigator: ObservableObject {
    @Published var currentPage = "index"
    @Published var currentTitle = "Logos InkPen Help"
    @Published var history: [String] = []
    @Published var historyIndex = -1
    
    var canGoBack: Bool {
        historyIndex > 0
    }
    
    var canGoForward: Bool {
        historyIndex < history.count - 1
    }
    
    func navigateTo(_ page: String, title: String = "") {
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)..<history.count)
        }
        
        history.append(page)
        historyIndex = history.count - 1
        currentPage = page
        currentTitle = title.isEmpty ? pageTitleFor(page) : title
    }
    
    func goBack() {
        if canGoBack {
            historyIndex -= 1
            currentPage = history[historyIndex]
            currentTitle = pageTitleFor(currentPage)
        }
    }
    
    func goForward() {
        if canGoForward {
            historyIndex += 1
            currentPage = history[historyIndex]
            currentTitle = pageTitleFor(currentPage)
        }
    }
    
    func goHome() {
        navigateTo("index", title: "Logos InkPen Help")
    }
    
    func search(_ query: String) {
        // Implement search functionality
    }
    
    private func pageTitleFor(_ page: String) -> String {
        switch page {
        case "index": return "Logos InkPen Help"
        case "getting-started": return "Getting Started"
        case "interface": return "Interface"
        case "tools": return "Tools"
        case "shapes": return "Shapes"
        case "panels": return "Panels"
        case "import": return "Import"
        case "export": return "Export"
        case "formats": return "File Formats"
        case "shortcuts": return "Keyboard Shortcuts"
        default: return "Help"
        }
    }
}

struct InternalHelpWebView: NSViewRepresentable {
    @ObservedObject var navigator: HelpNavigator
    let colorScheme: ColorScheme
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = false
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        if navigator.history.isEmpty {
            navigator.navigateTo("index")
        }
        
        loadPage(webView, page: navigator.currentPage)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadPage(webView, page: navigator.currentPage)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(navigator: navigator)
    }
    
    private func loadPage(_ webView: WKWebView, page: String) {
        if let htmlContent = loadHTMLContent(for: page) {
            let styledHTML = applyInternalStyles(to: htmlContent)
            webView.loadHTMLString(styledHTML, baseURL: nil)
        } else {
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body {
                        font-family: -apple-system, system-ui;
                        padding: 40px;
                        text-align: center;
                    }
                </style>
            </head>
            <body>
                <h2>Page Not Found</h2>
                <p>The help page "\(page)" could not be loaded.</p>
                <p><a href="index">Return to Home</a></p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
        }
    }
    
    private func loadHTMLContent(for page: String) -> String? {
        guard let helpBundle = Bundle.main.path(forResource: "LogosInkPenHelp", ofType: "help") else {
            return getBuiltInHelpContent(for: page)
        }
        
        let htmlPath = (helpBundle as NSString)
            .appendingPathComponent("Contents/Resources/en.lproj")
            .appending("/\(page).html")
        
        if let content = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            return content
        } else {
            return getBuiltInHelpContent(for: page)
        }
    }
    
    private func getBuiltInHelpContent(for page: String) -> String? {
        return InkPenHelpContent.getPage(page)?.content
    }
    
    private func applyInternalStyles(to html: String) -> String {
        let isDarkMode = colorScheme == .dark
        
        let internalStyles = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                padding: 30px;
                max-width: 800px;
                margin: 0 auto;
                line-height: 1.6;
                background-color: \(isDarkMode ? "#1e1e1e" : "#ffffff");
                color: \(isDarkMode ? "#e0e0e0" : "#333333");
            }
            
            h1 {
                color: \(isDarkMode ? "#ffffff" : "#000000");
                border-bottom: 2px solid \(isDarkMode ? "#0a84ff" : "#007AFF");
                padding-bottom: 10px;
                margin-top: 0;
            }
            
            h2 {
                color: \(isDarkMode ? "#d0d0d0" : "#555555");
                margin-top: 30px;
            }
            
            a {
                color: \(isDarkMode ? "#0a84ff" : "#007AFF");
                text-decoration: none;
                cursor: pointer;
            }
            
            a:hover {
                text-decoration: underline;
            }
            
            table {
                border-collapse: collapse;
                width: 100%;
                margin: 20px 0;
            }
            
            td {
                padding: 10px 12px;
                border-bottom: 1px solid \(isDarkMode ? "#404040" : "#dddddd");
            }
            
            td:first-child {
                font-weight: 500;
            }
            
            td:last-child {
                font-family: 'SF Mono', Monaco, 'Courier New', monospace;
                background: \(isDarkMode ? "#2a2a2a" : "#f5f5f5");
                border-radius: 4px;
            }
            
            ul, ol {
                margin: 20px 0;
            }
            
            li {
                margin: 10px 0;
            }
            
            .intro {
                font-size: 1.1em;
                margin: 20px 0;
            }
            
            .topics {
                margin-top: 30px;
            }
            
            .banner {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 40px;
                margin: -30px -30px 30px -30px;
                text-align: center;
            }
            
            .banner h1 {
                border: none;
                margin: 0;
                color: white;
            }
            
            code {
                background: \(isDarkMode ? "#2a2a2a" : "#f4f4f4");
                padding: 2px 6px;
                border-radius: 3px;
                font-family: 'SF Mono', Monaco, monospace;
            }
            
            .search-tip {
                background: \(isDarkMode ? "#2a2a2a" : "#f0f0f0");
                padding: 15px;
                border-radius: 8px;
                margin-top: 30px;
            }
        </style>
        """
        
        if let headRange = html.range(of: "</head>") {
            var modifiedHTML = html
            modifiedHTML.insert(contentsOf: internalStyles, at: headRange.lowerBound)
            return modifiedHTML
        } else if let htmlRange = html.range(of: "<html") {
            return html.replacingCharacters(in: htmlRange, with: "<html>\n<head>\n\(internalStyles)\n</head>\n<body>") + "</body></html>"
        } else {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                \(internalStyles)
            </head>
            <body>
                \(html)
            </body>
            </html>
            """
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let navigator: HelpNavigator
        
        init(navigator: HelpNavigator) {
            self.navigator = navigator
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    if url.scheme == "file" || url.scheme == nil {
                        let page = url.deletingPathExtension().lastPathComponent
                        navigator.navigateTo(page)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}