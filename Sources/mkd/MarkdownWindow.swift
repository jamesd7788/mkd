import AppKit
import SwiftUI

class MarkdownWindow: NSWindow {
    private var isStayOnTop = false

    init<Content: View>(title windowTitle: String, frameKey: String, content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = windowTitle
        setFrameAutosaveName("mkd-\(frameKey.hashValue)")
        contentView = NSHostingView(rootView: content)
        isReleasedWhenClosed = false

        // center only if no saved frame
        if !setFrameUsingName(frameAutosaveName) {
            center()
        }
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        // find the WKWebView and make it first responder so vim keys work immediately
        DispatchQueue.main.async {
            if let webView = self.findWebView(in: self.contentView) {
                self.makeFirstResponder(webView)
            }
        }
    }

    private func findWebView(in view: NSView?) -> NSView? {
        guard let view = view else { return nil }
        if NSStringFromClass(type(of: view)).contains("WKWebView") { return view }
        for sub in view.subviews {
            if let found = findWebView(in: sub) { return found }
        }
        return nil
    }

    func toggleStayOnTop() {
        isStayOnTop.toggle()
        level = isStayOnTop ? .floating : .normal
    }
}
