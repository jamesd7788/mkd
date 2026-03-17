import SwiftUI
@preconcurrency import WebKit

enum RenderMode {
    case markdown, progress
}

class WebViewModel: ObservableObject {
    var webView: WKWebView?
    var renderMode: RenderMode = .markdown
    private var fontSize: Int {
        get { UserDefaults.standard.object(forKey: "mkd-font-size") as? Int ?? 16 }
        set { UserDefaults.standard.set(newValue, forKey: "mkd-font-size") }
    }
    private var hasLoadedTemplate = false
    private var pendingContent: String?

    func loadTemplate() {
        guard let webView = webView else { return }

        let html = Self.buildHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    func loadContent(_ content: String) {
        guard let webView = webView, hasLoadedTemplate else {
            pendingContent = content
            return
        }

        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let fn = renderMode == .progress ? "renderProgress" : "renderMarkdown"
        webView.evaluateJavaScript("\(fn)(`\(escaped)`, \(fontSize))") { _, error in
            if let error = error {
                fputs("mkd: js error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    func templateDidLoad() {
        hasLoadedTemplate = true
        setTheme(currentTheme)
        if let content = pendingContent {
            pendingContent = nil
            loadContent(content)
        }
    }

    var currentTheme: String {
        get { UserDefaults.standard.string(forKey: "mkd-theme") ?? "github" }
        set { UserDefaults.standard.set(newValue, forKey: "mkd-theme") }
    }

    static let availableThemes = ["github", "literary", "brutalist", "typewriter", "nord", "gruvbox", "academic"]

    func setTheme(_ name: String) {
        currentTheme = name
        webView?.evaluateJavaScript("setTheme('\(name)')") { _, _ in }
    }

    func setConnectionStatus(_ status: ConnectionStatus) {
        webView?.evaluateJavaScript("setConnectionStatus('\(status.rawValue)')") { _, _ in }
    }

    func changeFontSize(delta: Int) {
        fontSize = max(8, min(32, fontSize + delta))
        webView?.evaluateJavaScript("setFontSize(\(fontSize))") { _, _ in }
    }

    private static func buildHTML() -> String {
        let bundle = Bundle.resolved
        let templateURL = bundle.url(forResource: "template", withExtension: "html", subdirectory: "Resources")!
        var html = try! String(contentsOf: templateURL, encoding: .utf8)

        let load: (String, String) -> String = { name, ext in
            let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources")!
            return try! String(contentsOf: url, encoding: .utf8)
        }

        html = html.replacingOccurrences(of: "/* {{MARKED_JS}} */", with: load("marked.min", "js"))
        html = html.replacingOccurrences(of: "/* {{HIGHLIGHT_JS}} */", with: load("highlight.min", "js"))
        html = html.replacingOccurrences(of: "/* {{DEFAULT_CSS}} */", with: load("default", "css"))
        html = html.replacingOccurrences(of: "/* {{HLJS_DARK_CSS}} */", with: load("hljs-dark", "css"))
        html = html.replacingOccurrences(of: "/* {{HLJS_LIGHT_CSS}} */", with: load("hljs-light", "css"))

        // user CSS override
        let userCSS = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mkd/style.css")
        if let custom = try? String(contentsOf: userCSS, encoding: .utf8) {
            html = html.replacingOccurrences(of: "/* {{USER_CSS}} */", with: custom)
        }

        return html
    }
}

struct WebView: NSViewRepresentable {
    let viewModel: WebViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        viewModel.webView = webView
        viewModel.loadTemplate()

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: WebViewModel

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.templateDidLoad()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url

            // allow loadHTMLString (about:blank) and internal navigation
            if url == nil || url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            // everything else gets blocked — open http(s) links in browser
            if let url = url, url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
            }

            decisionHandler(.cancel)
        }
    }
}
