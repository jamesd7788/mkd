import Foundation

class RemoteFileSource: FileSource {
    let host: String
    let remotePath: String
    var onChange: (() -> Void)?
    var onConnectionStatus: ((ConnectionStatus) -> Void)?

    var displayName: String {
        (remotePath as NSString).lastPathComponent
    }

    var displayPath: String {
        "\(host):\(remotePath)"
    }

    var isRemote: Bool { true }

    private let controlPath: String
    private var watchProcess: Process?
    private var pollTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "mkd.remotesource", qos: .utility)
    private var stopped = false

    init(host: String, remotePath: String) {
        self.host = host
        self.remotePath = remotePath
        self.controlPath = "/tmp/mkd-ssh-\(host)-\(ProcessInfo.processInfo.processIdentifier)"
    }

    // MARK: - SSH helpers

    private func runSSH(_ command: String, timeout: TimeInterval = 10) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=60",
            "-o", "ConnectTimeout=5",
            "-o", "BatchMode=yes",
            host,
            command
        ]

        let pipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = errPipe

        try proc.run()

        // wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            throw RemoteError.timeout
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard proc.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw RemoteError.ssh(errStr)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - FileSource

    func fetchContent() throws -> String {
        do {
            let content = try runSSH("cat \(shellQuote(remotePath))")
            setStatus(.connected)
            return content
        } catch {
            setStatus(.disconnected)
            throw error
        }
    }

    func start() {
        stopped = false
        queue.async { [weak self] in
            self?.probeAndWatch()
        }
    }

    func stop() {
        stopped = true
        watchProcess?.terminate()
        watchProcess = nil
        pollTimer?.cancel()
        pollTimer = nil

        // tear down control socket
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = [
            "-o", "ControlPath=\(controlPath)",
            "-O", "exit",
            host
        ]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    // MARK: - Watch strategy

    private func probeAndWatch() {
        guard !stopped else { return }

        // try fswatch first
        if let _ = try? runSSH("which fswatch") {
            startFSWatch()
            return
        }

        // try inotifywait
        if let _ = try? runSSH("which inotifywait") {
            startInotifyWatch()
            return
        }

        // fallback to polling
        startPolling()
    }

    private func startFSWatch() {
        guard !stopped else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=60",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            host,
            "while true; do fswatch -1 \(shellQuote(remotePath)) 2>/dev/null && echo CHANGED; done"
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.fireChange()
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self = self, !self.stopped else { return }
            self.setStatus(.reconnecting)
            self.queue.asyncAfter(deadline: .now() + 3) {
                self.startPolling()
            }
        }

        do {
            try proc.run()
            watchProcess = proc
            setStatus(.connected)
        } catch {
            startPolling()
        }
    }

    private func startInotifyWatch() {
        guard !stopped else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        proc.arguments = [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=60",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            host,
            "while true; do inotifywait -e modify,move_self,delete_self \(shellQuote(remotePath)) 2>/dev/null; done"
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.fireChange()
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self = self, !self.stopped else { return }
            self.setStatus(.reconnecting)
            self.queue.asyncAfter(deadline: .now() + 3) {
                self.startPolling()
            }
        }

        do {
            try proc.run()
            watchProcess = proc
            setStatus(.connected)
        } catch {
            startPolling()
        }
    }

    private func startPolling() {
        guard !stopped else { return }

        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)

        var lastHash: String? = nil

        timer.setEventHandler { [weak self] in
            guard let self = self, !self.stopped else { return }
            guard let hash = try? self.runSSH(
                "md5sum \(self.shellQuote(self.remotePath)) 2>/dev/null || md5 -q \(self.shellQuote(self.remotePath)) 2>/dev/null || stat -c %Y \(self.shellQuote(self.remotePath)) 2>/dev/null || stat -f %m \(self.shellQuote(self.remotePath))"
            ).trimmingCharacters(in: .whitespacesAndNewlines) else {
                self.setStatus(.disconnected)
                return
            }

            self.setStatus(.connected)
            if lastHash == nil {
                lastHash = hash
            } else if hash != lastHash {
                lastHash = hash
                self.fireChange()
            }
        }

        pollTimer = timer
        timer.resume()
    }

    private func fireChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.onChange?()
        }
    }

    private func setStatus(_ status: ConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStatus?(status)
        }
    }

    private func shellQuote(_ s: String) -> String {
        if s.hasPrefix("~/") {
            return "~/" + singleQuote(String(s.dropFirst(2)))
        }
        return singleQuote(s)
    }

    private func singleQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    deinit {
        stop()
    }
}

enum RemoteError: LocalizedError {
    case timeout
    case ssh(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "ssh command timed out"
        case .ssh(let msg): return msg.isEmpty ? "ssh command failed" : msg
        }
    }
}
