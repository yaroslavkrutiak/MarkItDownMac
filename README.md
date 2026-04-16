# MarkItDownMac

A native macOS app that converts documents to Markdown using the [markitdown](https://github.com/microsoft/markitdown) Python CLI. Drag-and-drop or right-click files in Finder to convert PDFs, DOCX, PPTX, spreadsheets, images, audio, and more — whatever your installed version of markitdown supports.

## Features

- **Drag-and-drop window** — drop a file or click "Select File..." to convert
- **Finder Quick Action** — right-click any file → Services → "Convert to Markdown"
- **Auto format detection** — supported formats are read from the installed markitdown, not hardcoded
- **Collision-safe output** — `report.pdf` → `report.md`, and if that exists → `report-1.md`, `report-2.md`, etc.
- **Notifications** — Quick Action conversions show a system notification on completion
- **Graceful error handling** — clear messages when markitdown is missing, the format is unsupported, or conversion fails

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (to build)
- Python 3.8+
- markitdown CLI

## Installation

### 1. Install Python (if needed)

macOS ships with Python removed since Monterey. Install via Homebrew:

```sh
brew install python
```

Or use [pyenv](https://github.com/pyenv/pyenv):

```sh
brew install pyenv
pyenv install 3.12
pyenv global 3.12
```

### 2. Install markitdown

```sh
pip install markitdown
```

Verify it works:

```sh
markitdown --help
```

Or run the included setup script:

```sh
./scripts/setup.sh
```

### 3. Build the app

Open the project in Xcode:

```sh
open MarkItDownMac.xcodeproj
```

Select the **MarkItDownMac** scheme, then **Product → Run** (⌘R).

To build from the command line (requires Xcode, not just Command Line Tools):

```sh
xcodebuild -project MarkItDownMac.xcodeproj -scheme MarkItDownMac -configuration Release build
```

### 4. Enable the Finder Quick Action

After running the app at least once:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**
2. Find **Convert to Markdown** under Files and Folders
3. Enable it

You can now right-click any file in Finder → **Services → Convert to Markdown**.

## Usage

### Window

Launch the app. Either drag a file onto the drop zone or click **Select File...** (⌘O). The converted `.md` file is created next to the original. Click the filename in the success screen to reveal it in Finder.

### Finder Quick Action

Right-click one or more files in Finder → **Services → Convert to Markdown**. A notification appears when each file is done. The output goes in the same directory as the source file.

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
│   └── SupportedFormats.swift           # Category grouping for UI labels
├── UI/
│   ├── ContentView.swift                # State machine: idle → converting → done/error
│   ├── DropZoneView.swift               # Drag-and-drop target
│   └── ConversionResultView.swift       # Success screen with Reveal in Finder
├── Resources/
│   ├── Info.plist                       # NSServices declaration
│   └── MarkItDownMac.entitlements       # App Sandbox entitlements
└── scripts/
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

The UI layer never references `MarkItDownCLIImplementation` directly. To add a different backend (e.g. a Python bridge or a WebAssembly build), conform to `ConverterImplementation` and pass it to `ConverterBridge`.

## Troubleshooting

| Problem | Fix |
|---|---|
| "markitdown is not installed" in the app | Run `pip install markitdown` and relaunch |
| Quick Action doesn't appear in Finder | Run the app once, then enable in System Settings → Keyboard → Keyboard Shortcuts → Services |
| Conversion times out | Large files may exceed the 60s default. This is configurable in `ShellRunner.defaultTimeout` |
| markitdown is installed but app can't find it | The app searches `~/.pyenv/shims`, `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, then `which`. Make sure markitdown is in one of these |

## License

MIT
