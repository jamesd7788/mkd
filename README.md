# mkd

A minimal macOS markdown viewer. Opens a native window with rendered markdown and live-reloads on file changes.

Built for terminal workflows where you want to preview `.md` files without leaving your editor.

## Install

### Homebrew

```bash
brew tap jamesd7788/tap
brew install mkd
```

### From source

Requires macOS 13+ and Swift 5.9+.

```bash
swift build -c release
ln -sf $(swift build -c release --show-bin-path)/mkd ~/.local/bin/mkd
```

## Usage

```bash
mkd /path/to/file.md                          # local file
mkd host:path/to/file.md                       # remote file via SSH
cat notes.md | mkd                             # pipe from stdin
gh pr view 42 --json body -q .body | mkd       # pipe anything
mkd --watch-cmd "some-command" --interval 3    # re-run command every 3s
mkd --progress tasks.md                        # task/progress viewer
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
| `j / k` | Scroll down / up |
| `d / u` | Page down / up |
| `g / G` | Jump to top / bottom |
| `/` | Open search |
| `n / N` | Next / previous match |
| `Esc` | Close search |

Font size, theme, window position and size are persisted across sessions.

## Features

- **Live reload** — watches file and parent directory (handles atomic saves from vim, etc.)
- **Stdin support** — pipe markdown from any command
- **Watch mode** — `--watch-cmd` re-runs a command on interval, renders output as markdown
- **Progress mode** — `--progress` renders task lists as a navigable slide deck with progress bar
- **Remote viewing** — view files on remote hosts via SSH with auto-reconnect
- **6 themes** — github, dracula, nord, gruvbox, solarized, rose (persisted, follows system dark/light)
- **Vim keybindings** — `j/k` scroll, `/` search, `g/G` top/bottom, `d/u` page down/up, `n/N` next/prev
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
├── main.swift             # CLI entry, arg parsing, NSApplication bootstrap
├── AppDelegate.swift      # Window creation, menu bar, theme menu
├── AppIcon.swift          # SVG-based app icon generated at runtime
├── MarkdownWindow.swift   # NSWindow config, frame persistence
├── ContentView.swift      # SwiftUI view, file watcher lifecycle
├── WebView.swift          # WKWebView wrapper, rendering, themes
├── FileSource.swift       # FileSource protocol
├── FileWatcher.swift      # Local file/directory watcher
├── RemoteFileSource.swift # SSH remote file watcher
├── StdinSource.swift      # Stdin pipe source
├── CommandSource.swift    # --watch-cmd polling source
├── BundleFix.swift        # Bundle resolution for symlinks
└── Resources/
    ├── template.html      # HTML shell + themes + progress mode
    ├── marked.min.js      # Markdown parser (v15)
    ├── highlight.min.js   # Syntax highlighter (v11)
    ├── default.css        # Base styles + progress mode
    ├── hljs-dark.css      # GitHub Dark code theme
    └── hljs-light.css     # GitHub Light code theme
```

## How It Works

Markdown is parsed client-side in the WebView using `marked.js`. A `WKWebView` loads a single HTML template with all JS/CSS inlined. On file change, the raw markdown string is passed to JavaScript via `evaluateJavaScript`, re-rendered, and highlight.js runs a post-render pass on code blocks. No Swift markdown parsing dependencies, no network access.

## License

MIT
