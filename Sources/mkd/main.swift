import AppKit

var args = Array(CommandLine.arguments.dropFirst())
let progressMode = args.contains("--progress")
args.removeAll { $0 == "--progress" }

// --watch-cmd "command"
var watchCmd: String? = nil
if let idx = args.firstIndex(of: "--watch-cmd"), idx + 1 < args.count {
    watchCmd = args[idx + 1]
    args.removeSubrange(idx...idx+1)
} else if args.contains("--watch-cmd") {
    fputs("mkd: --watch-cmd requires an argument\n", stderr)
    exit(1)
}

// --interval N (for --watch-cmd, default 2s)
var watchInterval: TimeInterval = 2.0
if let idx = args.firstIndex(of: "--interval"), idx + 1 < args.count {
    if let val = TimeInterval(args[idx + 1]) {
        watchInterval = max(0.5, val)
    }
    args.removeSubrange(idx...idx+1)
}

let source: any FileSource

if let cmd = watchCmd {
    // --watch-cmd mode
    let cmdSource = CommandSource(command: cmd, interval: watchInterval)
    do {
        _ = try cmdSource.fetchContent()
    } catch {
        fputs("mkd: command failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
    source = cmdSource
} else if args.isEmpty {
    // no args — try stdin if not a tty
    guard !isatty(STDIN_FILENO).bool else {
        fputs("usage: mkd [--progress] <file.md>\n", stderr)
        fputs("       mkd [--progress] host:path/to/file.md\n", stderr)
        fputs("       mkd [--progress] --watch-cmd \"command\" [--interval N]\n", stderr)
        fputs("       command | mkd [--progress]\n", stderr)
        exit(1)
    }
    source = StdinSource()
} else {
    let arg = args[0]

    if isRemoteArg(arg) {
        let parts = arg.split(separator: ":", maxSplits: 1)
        let host = String(parts[0])
        var remotePath = String(parts[1])

        if !remotePath.hasPrefix("/") && !remotePath.hasPrefix("~") {
            remotePath = "~/\(remotePath)"
        }

        guard hasMarkdownExtension(remotePath) else {
            fputs("mkd: not a markdown file: \(remotePath)\n", stderr)
            exit(1)
        }

        let remote = RemoteFileSource(host: host, remotePath: remotePath)

        do {
            _ = try remote.fetchContent()
        } catch {
            fputs("mkd: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        source = remote
    } else {
        let path = (arg as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path).standardizedFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            fputs("mkd: file not found: \(url.path)\n", stderr)
            exit(1)
        }

        guard hasMarkdownExtension(url.path) else {
            fputs("mkd: not a markdown file: \(url.path)\n", stderr)
            exit(1)
        }

        source = LocalFileSource(url: url)
    }
}

func isRemoteArg(_ s: String) -> Bool {
    guard s.contains(":") else { return false }
    let first = s.first!
    return first != "/" && first != "~" && first != "."
}

func hasMarkdownExtension(_ path: String) -> Bool {
    let ext = (path as NSString).pathExtension.lowercased()
    return ext == "md" || ext == "markdown"
}

// helper: isatty returns Int32, need Bool
extension Int32 {
    var bool: Bool { self != 0 }
}

let app = NSApplication.shared
let delegate = AppDelegate(source: source, progressMode: progressMode)
app.delegate = delegate
app.run()
