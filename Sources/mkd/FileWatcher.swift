import Foundation

class LocalFileSource: ObservableObject, FileSource {
    let url: URL
    var onChange: (() -> Void)?
    var onConnectionStatus: ((ConnectionStatus) -> Void)?

    var displayName: String { url.lastPathComponent }
    var displayPath: String { url.path }
    var isRemote: Bool { false }

    private var fileSource_: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "mkd.filewatcher", qos: .utility)
    private var lastModified: Date?

    init(url: URL) {
        self.url = url
        self.lastModified = Self.modDate(url)
    }

    func fetchContent() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func start() {
        watchFile()
        watchDirectory()
    }

    func stop() {
        fileSource_?.cancel()
        dirSource?.cancel()
        fileSource_ = nil
        dirSource = nil
    }

    private func watchFile() {
        fileSource_?.cancel()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        fileSource_ = source
        source.resume()
    }

    // watch parent dir to catch atomic saves (write to tmp + rename)
    private func watchDirectory() {
        let dirURL = url.deletingLastPathComponent()
        let fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            // check if our file was modified
            let newMod = Self.modDate(self.url)
            if newMod != self.lastModified {
                self.lastModified = newMod
                self.handleChange()
                // re-watch the file (fd may have changed after atomic save)
                DispatchQueue.main.async {
                    self.watchFile()
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        dirSource = source
        source.resume()
    }

    private func handleChange() {
        // debounce: small delay to let writes finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.onChange?()
        }
    }

    private static func modDate(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    deinit {
        stop()
    }
}
