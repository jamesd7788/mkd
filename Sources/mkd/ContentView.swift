import SwiftUI

struct ContentView: View {
    let viewModel: WebViewModel
    let fetchContent: () throws -> String
    let startWatching: (@escaping () -> Void) -> Void
    let stopWatching: () -> Void
    let onStatusChange: ((@escaping (ConnectionStatus) -> Void) -> Void)?

    var body: some View {
        WebView(viewModel: viewModel)
            .onAppear {
                loadMarkdown()
                startWatching { [self] in
                    loadMarkdown()
                }
                onStatusChange? { [self] status in
                    viewModel.setConnectionStatus(status)
                }
            }
            .onDisappear {
                stopWatching()
            }
    }

    private func loadMarkdown() {
        guard let content = try? fetchContent() else { return }
        viewModel.loadMarkdown(content)
    }
}
