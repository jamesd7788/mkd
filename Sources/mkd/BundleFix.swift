import Foundation

// SPM's generated Bundle.module uses Bundle.main.bundleURL which doesn't
// resolve symlinks (e.g. homebrew's /opt/homebrew/bin/mkd -> Cellar/...).
// This provides a fallback that resolves the real path of the executable.
extension Bundle {
    static let resolved: Bundle = {
        // try SPM's default first
        if let url = Bundle.main.url(forResource: "Resources", withExtension: nil, subdirectory: "mkd_mkd.bundle"),
           let bundle = Bundle(url: url.deletingLastPathComponent()) {
            return bundle
        }

        // resolve symlinks and look next to the real binary
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
            .resolvingSymlinksInPath()
        let realDir = execURL.deletingLastPathComponent()
        let bundlePath = realDir.appendingPathComponent("mkd_mkd.bundle")

        if let bundle = Bundle(path: bundlePath.path) {
            return bundle
        }

        // last resort: Bundle.module (will fatalError if also broken)
        return Bundle.module
    }()
}
