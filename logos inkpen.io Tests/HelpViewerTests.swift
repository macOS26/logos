import XCTest
@testable import logos_inkpen_io

class HelpViewerTests: XCTestCase {

    func testHelpNavigatorInitialization() {
        let navigator = HelpNavigator()

        XCTAssertEqual(navigator.currentPage, "index")
        XCTAssertEqual(navigator.currentTitle, "Logos InkPen Help")
        XCTAssertTrue(navigator.history.isEmpty)
        XCTAssertEqual(navigator.historyIndex, -1)
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }

    func testHelpNavigatorNavigation() {
        let navigator = HelpNavigator()

        navigator.navigateTo("getting-started")
        XCTAssertEqual(navigator.currentPage, "getting-started")
        XCTAssertEqual(navigator.currentTitle, "Getting Started")
        XCTAssertEqual(navigator.history.count, 1)
        XCTAssertEqual(navigator.historyIndex, 0)
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)

        navigator.navigateTo("tools")
        XCTAssertEqual(navigator.currentPage, "tools")
        XCTAssertEqual(navigator.currentTitle, "Tools")
        XCTAssertEqual(navigator.history.count, 2)
        XCTAssertEqual(navigator.historyIndex, 1)
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }

    func testHelpNavigatorBackForward() {
        let navigator = HelpNavigator()

        navigator.navigateTo("index")
        navigator.navigateTo("tools")
        navigator.navigateTo("shortcuts")

        XCTAssertEqual(navigator.currentPage, "shortcuts")
        XCTAssertTrue(navigator.canGoBack)

        navigator.goBack()
        XCTAssertEqual(navigator.currentPage, "tools")
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)

        navigator.goBack()
        XCTAssertEqual(navigator.currentPage, "index")
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)

        navigator.goForward()
        XCTAssertEqual(navigator.currentPage, "tools")
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)
    }

    func testHelpNavigatorGoHome() {
        let navigator = HelpNavigator()

        navigator.navigateTo("tools")
        navigator.navigateTo("shortcuts")

        XCTAssertEqual(navigator.currentPage, "shortcuts")

        navigator.goHome()
        XCTAssertEqual(navigator.currentPage, "index")
        XCTAssertEqual(navigator.currentTitle, "Logos InkPen Help")
    }

    func testHelpContentRetrieval() {
        let indexPage = InkPenHelpContent.getPage("index")
        XCTAssertNotNil(indexPage)
        XCTAssertEqual(indexPage?.title, "Logos InkPen Help")
        XCTAssertTrue(indexPage?.content.contains("Welcome to Logos InkPen") ?? false)

        let toolsPage = InkPenHelpContent.getPage("tools")
        XCTAssertNotNil(toolsPage)
        XCTAssertEqual(toolsPage?.title, "Tools Reference")
        XCTAssertTrue(toolsPage?.content.contains("Selection Tools") ?? false)

        let nonExistentPage = InkPenHelpContent.getPage("nonexistent")
        XCTAssertNil(nonExistentPage)
    }

    func testHelpContentSearch() {
        let results = InkPenHelpContent.searchPages("keyboard")
        XCTAssertTrue(results.contains("shortcuts"))

        let toolResults = InkPenHelpContent.searchPages("pen tool")
        XCTAssertTrue(toolResults.contains("tools"))

        let noResults = InkPenHelpContent.searchPages("xyzabc123")
        XCTAssertTrue(noResults.isEmpty)
    }

    func testHelpPageHTMLGeneration() {
        let page = InkPenHelpContent.getPage("index")
        XCTAssertNotNil(page)

        let html = page?.fullHTML ?? ""
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("<head>"))
        XCTAssertTrue(html.contains("<body>"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("font-family: -apple-system"))
    }

    func testInternalHelpViewerSingleton() {
        let instance1 = InternalHelpViewer.shared
        let instance2 = InternalHelpViewer.shared

        XCTAssertTrue(instance1 === instance2)
    }
}
