import Foundation

class StdinSource: FileSource {
    var onChange: (() -> Void)?
    var onConnectionStatus: ((ConnectionStatus) -> Void)?

    var displayName: String { "stdin" }
    var displayPath: String { "mkd-stdin" }
    var isRemote: Bool { false }

    private let tempURL: URL
    private var fileSource: LocalFileSource?

    init() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkd-stdin-\(ProcessInfo.processInfo.processIdentifier).md")
        self.tempURL = tmp

        // read all of stdin and write to temp file
        let data = FileHandle.standardInput.readDataToEndOfFile()
        try! data.write(to: tmp)

        self.fileSource = LocalFileSource(url: tmp)
    }

    func fetchContent() throws -> String {
        try String(contentsOf: tempURL, encoding: .utf8)
    }

    func start() {
        fileSource?.onChange = { [weak self] in
            self?.onChange?()
        }
        fileSource?.start()
    }

    func stop() {
        fileSource?.stop()
        try? FileManager.default.removeItem(at: tempURL)
    }

    deinit {
        stop()
    }
}
