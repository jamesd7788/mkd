import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: mkd <file.md>\n", stderr)
    fputs("       mkd host:path/to/file.md\n", stderr)
    exit(1)
}

let arg = CommandLine.arguments[1]

func isRemoteArg(_ s: String) -> Bool {
    guard s.contains(":") else { return false }
    // local paths start with /, ~, or .
    let first = s.first!
    return first != "/" && first != "~" && first != "."
}

func hasMarkdownExtension(_ path: String) -> Bool {
    let ext = (path as NSString).pathExtension.lowercased()
    return ext == "md" || ext == "markdown"
}

let source: any FileSource

if isRemoteArg(arg) {
    let parts = arg.split(separator: ":", maxSplits: 1)
    let host = String(parts[0])
    var remotePath = String(parts[1])

    // prepend ~/ to relative remote paths
    if !remotePath.hasPrefix("/") && !remotePath.hasPrefix("~") {
        remotePath = "~/\(remotePath)"
    }

    guard hasMarkdownExtension(remotePath) else {
        fputs("mkd: not a markdown file: \(remotePath)\n", stderr)
        exit(1)
    }

    let remote = RemoteFileSource(host: host, remotePath: remotePath)

    // validate connection + file existence before launching UI
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

let app = NSApplication.shared
let delegate = AppDelegate(source: source)
app.delegate = delegate
app.run()
