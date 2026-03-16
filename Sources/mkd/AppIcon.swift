import AppKit

enum AppIcon {
    static func create() -> NSImage {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
          <defs>
            <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#1a1a2e"/>
              <stop offset="100%" stop-color="#16213e"/>
            </linearGradient>
          </defs>
          <rect width="512" height="512" rx="100" fill="url(#bg)"/>
          <text x="256" y="310" text-anchor="middle" font-family="-apple-system,SF Pro,Helvetica" font-size="280" font-weight="800" fill="#e2e8f0" letter-spacing="-15">md</text>
          <text x="258" y="420" text-anchor="middle" font-family="-apple-system,SF Pro,Helvetica" font-size="80" font-weight="300" fill="#64748b" letter-spacing="4">viewer</text>
          <rect x="60" y="56" width="100" height="6" rx="3" fill="#818cf8" opacity="0.7"/>
          <rect x="60" y="74" width="68" height="6" rx="3" fill="#818cf8" opacity="0.4"/>
        </svg>
        """

        guard let data = svg.data(using: .utf8),
              let image = NSImage(data: data) else {
            return NSImage()
        }

        // render to bitmap at 512x512 for crisp dock icon
        let size = NSSize(width: 512, height: 512)
        let bitmap = NSImage(size: size)
        bitmap.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        bitmap.unlockFocus()

        return bitmap
    }
}
