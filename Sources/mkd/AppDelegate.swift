import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let source: any FileSource
    let progressMode: Bool
    var window: MarkdownWindow?
    let viewModel = WebViewModel()

    init(source: any FileSource, progressMode: Bool = false) {
        self.source = source
        self.progressMode = progressMode
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()

        if progressMode {
            viewModel.renderMode = .progress
        }

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
        let title = progressMode ? "\(source.displayName) — progress" : source.displayName
        window = MarkdownWindow(
            title: title,
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

        viewMenu.addItem(.separator())

        let themeMenu = NSMenu(title: "Theme")
        for name in WebViewModel.availableThemes {
            let item = NSMenuItem(title: name.capitalized, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.representedObject = name
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        viewMenu.addItem(themeItem)

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

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        viewModel.setTheme(name)
        // update checkmarks
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(selectTheme(_:)),
           let name = menuItem.representedObject as? String {
            menuItem.state = name == viewModel.currentTheme ? .on : .off
        }
        return true
    }
}
