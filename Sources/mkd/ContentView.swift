import SwiftUI

struct ContentView: View {
    let fileURL: URL
    let viewModel: WebViewModel
    @StateObject private var watcher: FileWatcher

    init(fileURL: URL, viewModel: WebViewModel) {
        self.fileURL = fileURL
        self.viewModel = viewModel
        _watcher = StateObject(wrappedValue: FileWatcher(url: fileURL))
    }

    var body: some View {
        WebView(viewModel: viewModel)
            .onAppear {
                loadMarkdown()
                watcher.onChange = { [self] in
                    loadMarkdown()
                }
                watcher.start()
            }
    }

    private func loadMarkdown() {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        viewModel.loadMarkdown(content)
    }
}
