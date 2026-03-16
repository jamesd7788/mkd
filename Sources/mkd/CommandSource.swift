import Foundation

class CommandSource: FileSource {
    var onChange: (() -> Void)?
    var onConnectionStatus: ((ConnectionStatus) -> Void)?

    let command: String
    let interval: TimeInterval

    var displayName: String { "watch: \(command)" }
    var displayPath: String { "mkd-watch-\(command.hashValue)" }
    var isRemote: Bool { false }

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "mkd.commandsource", qos: .utility)
    private var lastContent: String?

    init(command: String, interval: TimeInterval = 2.0) {
        self.command = command
        self.interval = interval
    }

    func fetchContent() throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", command]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw NSError(
                domain: "mkd",
                code: Int(proc.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "command exited with status \(proc.terminationStatus)"]
            )
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard let content = try? self.fetchContent() else { return }
            if content != self.lastContent {
                self.lastContent = content
                DispatchQueue.main.async {
                    self.onChange?()
                }
            }
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        stop()
    }
}
