import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let source: any FileSource
    var window: MarkdownWindow?
    let viewModel = WebViewModel()

    init(source: any FileSource) {
        self.source = source
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()

        let src = source
        let contentView = ContentView(
            viewModel: viewModel,
            fetchContent: { try src.fetchContent() },
            startWatching: { callback in
                src.onChange = callback
                src.start()
            },
            stopWatching: { src.stop() },
            onStatusChange: src.isRemote ? { callback in
                src.onConnectionStatus = callback
            } : nil
        )
        window = MarkdownWindow(
            title: source.displayName,
            frameKey: source.displayPath,
            content: contentView
        )
        window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.window?.orderFrontRegardless()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        source.stop()
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // app menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About mkd", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit mkd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // view menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Increase Font Size", action: #selector(increaseFontSize), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Decrease Font Size", action: #selector(decreaseFontSize), keyEquivalent: "-")
        viewMenu.addItem(.separator())

        let stayOnTopItem = NSMenuItem(title: "Stay on Top", action: #selector(toggleStayOnTop), keyEquivalent: "T")
        stayOnTopItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(stayOnTopItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // edit menu (for copy)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func increaseFontSize() {
        viewModel.changeFontSize(delta: 1)
    }

    @objc private func decreaseFontSize() {
        viewModel.changeFontSize(delta: -1)
    }

    @objc private func toggleStayOnTop() {
        window?.toggleStayOnTop()
    }
}
