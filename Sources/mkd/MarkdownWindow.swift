import AppKit
import SwiftUI

class MarkdownWindow: NSWindow {
    private var isStayOnTop = false

    init<Content: View>(fileURL: URL, content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = fileURL.lastPathComponent
        setFrameAutosaveName("mkd-\(fileURL.path.hashValue)")
        contentView = NSHostingView(rootView: content)
        isReleasedWhenClosed = false

        // center only if no saved frame
        if !setFrameUsingName(frameAutosaveName) {
            center()
        }
    }

    func toggleStayOnTop() {
        isStayOnTop.toggle()
        level = isStayOnTop ? .floating : .normal
    }
}
