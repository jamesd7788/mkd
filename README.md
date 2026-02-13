# mkd

A minimal macOS markdown viewer. Opens a native window with rendered markdown and live-reloads on file changes.

Built for terminal workflows where you want to preview `.md` files without leaving your editor.

## Install

Requires macOS 13+ and Swift 5.9+.

```bash
# build
swift build -c release

# symlink to PATH
ln -sf $(swift build -c release --show-bin-path)/mkd /usr/local/bin/mkd

# or bundle as .app
./scripts/bundle-app.sh
cp -R .build/arm64-apple-macosx/release/mkd.app /Applications/
```

## Usage

```bash
mkd /path/to/file.md
```

Edit the file in any editor and the viewer updates automatically.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd +` | Increase font size |
| `Cmd -` | Decrease font size |
| `Cmd Shift T` | Toggle stay-on-top |
| `Cmd Q` | Quit |
| `Cmd C` | Copy |
| `Cmd A` | Select all |

Font size is persisted across sessions. Window position and size are restored on next open.

## Features

- **Live reload** — watches file and parent directory (handles atomic saves from vim, etc.)
- **Syntax highlighting** — [highlight.js](https://highlightjs.org/) with GitHub themes
- **Dark/light mode** — follows system appearance
- **Fully offline** — all JS/CSS bundled, network requests blocked. Links open in default browser.
- **GFM support** — tables, task lists, strikethrough, fenced code blocks via [marked](https://marked.js.org/)
- **Scroll preservation** — maintains proportional scroll position on reload

## Custom CSS

Create `~/.config/mkd/style.css` to override default styles. It's injected after all other stylesheets.

## Project Structure

```
Sources/mkd/
├── main.swift           # CLI entry, NSApplication bootstrap
├── AppDelegate.swift    # Window creation, menu bar
├── MarkdownWindow.swift # NSWindow config, frame persistence
├── ContentView.swift    # SwiftUI view, file watcher lifecycle
├── WebView.swift        # WKWebView wrapper, markdown rendering
├── FileWatcher.swift    # DispatchSource file/directory watcher
└── Resources/
    ├── template.html    # HTML shell
    ├── marked.min.js    # Markdown parser (v15)
    ├── highlight.min.js # Syntax highlighter (v11)
    ├── default.css      # Base styles (dark/light)
    ├── hljs-dark.css    # GitHub Dark code theme
    └── hljs-light.css   # GitHub Light code theme
```

## How It Works

Markdown is parsed client-side in the WebView using `marked.js`. A `WKWebView` loads a single HTML template with all JS/CSS inlined. On file change, the raw markdown string is passed to JavaScript via `evaluateJavaScript`, re-rendered, and highlight.js runs a post-render pass on code blocks. No Swift markdown parsing dependencies, no network access.

## License

MIT
