import AppKit

guard CommandLine.arguments.count > 1 else {
    fputs("usage: mkd <file.md>\n", stderr)
    exit(1)
}

let path = (CommandLine.arguments[1] as NSString).expandingTildeInPath
let url = URL(fileURLWithPath: path).standardizedFileURL

guard FileManager.default.fileExists(atPath: url.path) else {
    fputs("mkd: file not found: \(url.path)\n", stderr)
    exit(1)
}

guard url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown" else {
    fputs("mkd: not a markdown file: \(url.path)\n", stderr)
    exit(1)
}

let app = NSApplication.shared
let delegate = AppDelegate(fileURL: url)
app.delegate = delegate
app.run()
