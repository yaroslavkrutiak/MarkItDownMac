# MarkItDownMac

A native macOS app that converts documents to Markdown using the [markitdown](https://github.com/microsoft/markitdown) Python CLI. Drag-and-drop or right-click files in Finder to convert PDFs, DOCX, PPTX, spreadsheets, images, audio, and more — whatever your installed version of markitdown supports.

## Features

- **Drag-and-drop window** — drop a file or click "Select File..." to convert
- **Finder Quick Action** — right-click any file → Services → "Convert to Markdown"
- **Auto format detection** — supported formats are read from the installed markitdown, not hardcoded
- **Collision-safe output** — `report.pdf` → `report.md`, and if that exists → `report-1.md`, `report-2.md`, etc.
- **Notifications** — Quick Action conversions show a system notification on completion
- **Debug logging** — toggle the bug icon to write detailed logs on failure to `~/Library/Logs/MarkItDownMac/`
- **Graceful error handling** — clear messages when markitdown is missing, the format is unsupported, or conversion fails

## Prerequisites

- macOS 13.0 (Ventura) or later
- Python 3.8+
- markitdown CLI

Install Python (if needed):

```sh
brew install python
```

Install markitdown:

```sh
pip install markitdown
```

## Install the App

### Option A: Homebrew (recommended)

No quarantine warnings, automatic updates.

```sh
brew tap yaroslavkrutiak/markitdownmac https://github.com/yaroslavkrutiak/MarkItDownMac.git
brew install --cask markitdownmac
```

To upgrade later:

```sh
brew upgrade --cask markitdownmac
```

### Option B: Install script

One command that downloads the latest release, strips quarantine, and copies to `/Applications`:

```sh
curl -fsSL https://raw.githubusercontent.com/yaroslavkrutiak/MarkItDownMac/main/scripts/install.sh | bash
```

### Option C: Manual download

1. Go to [Releases](https://github.com/yaroslavkrutiak/MarkItDownMac/releases/latest)
2. Download **MarkItDownMac.zip**
3. Extract it
4. Run in Terminal: `xattr -cr MarkItDownMac.app`
5. Move to `/Applications`

### Option D: Build from source

Requires Xcode 15+.

```sh
git clone https://github.com/yaroslavkrutiak/MarkItDownMac.git
cd MarkItDownMac
open MarkItDownMac.xcodeproj
```

Select the **MarkItDownMac** scheme, then **Product → Run** (⌘R).

> **Note:** The app is not notarized. If macOS shows a "damaged" or unidentified-developer warning after building, run `xattr -cr /path/to/MarkItDownMac.app` before launching.

## Setup: Finder Quick Action

After launching the app at least once:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**
2. Find **Convert to Markdown** under Files and Folders
3. Enable it

Now right-click any file in Finder → **Services → Convert to Markdown**.

## Usage

### Window

Launch the app. Drop a file onto the drop zone or click **Select File...** (⌘O). The converted `.md` file is created next to the original. Click the filename to reveal it in Finder.

### Finder Quick Action

Right-click one or more files in Finder → **Services → Convert to Markdown**. A notification appears when done. Output goes in the same directory as the source file.

### Debug Logging

Click the bug icon in the bottom-right corner to enable debug mode. When a conversion fails, a log file is written to `~/Library/Logs/MarkItDownMac/` containing the exact command, exit code, stdout, and stderr. An "Open Log" link appears on the error screen.

## Project Structure

```
MarkItDownMac/
├── App/
│   ├── MarkItDownApp.swift              # @main entry, SwiftUI WindowGroup
│   └── AppDelegate.swift                # Finder Service handler, notifications
├── Bridge/
│   ├── ConverterImplementation.swift    # Protocol — the implementor interface
│   ├── MarkItDownCLIImplementation.swift # Concrete implementor (shells out to markitdown)
│   └── ConverterBridge.swift            # Abstraction the UI talks to
├── Core/
│   ├── ShellRunner.swift                # Process wrapper with configurable timeout
│   ├── FileOutputManager.swift          # Collision-safe .md output paths
│   ├── SupportedFormats.swift           # Category grouping for UI labels
│   └── DebugLogger.swift               # Timestamped failure logs
├── UI/
│   ├── ContentView.swift                # State machine: idle → converting → done/error
│   ├── DropZoneView.swift               # Drag-and-drop target
│   └── ConversionResultView.swift       # Success screen with Reveal in Finder
├── Resources/
│   ├── Info.plist                       # NSServices declaration
│   └── MarkItDownMac.entitlements       # App Sandbox entitlements
└── scripts/
    ├── install.sh                       # One-liner installer
    ├── setup.sh                         # pip install markitdown
    └── generate-xcodeproj.sh            # Regenerate .xcodeproj via xcodegen
```

## Architecture

The app uses the **Bridge pattern** to separate the UI from the conversion backend:

```
┌─────────────┐       ┌─────────────────┐       ┌──────────────────────────┐
│  SwiftUI    │──────▶│ ConverterBridge  │──────▶│ ConverterImplementation  │
│  (ContentView)      │ (abstraction)    │       │ (protocol)               │
└─────────────┘       └─────────────────┘       └──────────┬───────────────┘
                                                           │
                                                ┌──────────▼───────────────┐
                                                │ MarkItDownCLIImpl        │
                                                │ (shells out to CLI)      │
                                                └──────────────────────────┘
```

The UI layer never references `MarkItDownCLIImplementation` directly. To add a different backend, conform to `ConverterImplementation` and pass it to `ConverterBridge`.

## Troubleshooting

| Problem | Fix |
|---|---|
| "markitdown is not installed" in the app | Run `pip install markitdown` and relaunch |
| Quick Action doesn't appear in Finder | Run the app once, then enable in System Settings → Keyboard → Keyboard Shortcuts → Services |
| Conversion times out | Large files may exceed the 60s default. This is configurable in `ShellRunner.defaultTimeout` |
| markitdown installed but app can't find it | The app searches `~/.pyenv/shims`, `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, then `which`. Make sure markitdown is in one of these |
| "Damaged" or quarantine warning | The app is not notarized. Run `xattr -cr MarkItDownMac.app` to clear the quarantine flag. Homebrew and the install script do this automatically. |

## License

MIT
