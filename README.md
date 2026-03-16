# Keypunch

A macOS menu bar app that launches applications via global keyboard shortcuts.

## Features

- Register global keyboard shortcuts to launch any macOS application
- Menu bar icon with quick access to all registered shortcuts
- Settings window to add, edit, and remove shortcuts
- App icons and shortcut keys displayed in menu and settings
- Persistent storage — shortcuts survive app restarts
- Duplicate app detection

## Requirements

- macOS 15.5+
- Xcode 16+

## Tooling

This repository uses `mise` to pin the CLI tools used for linting.

```bash
brew install mise
mise trust
mise install
```

## Build

```bash
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' build
```

## Run

Open in Xcode and press Cmd+R, or:

```bash
open "$(xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -showBuildSettings | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/Keypunch.app"
```

## Lint

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
```

## Test

```bash
# All tests
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' test

# Unit tests only
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' -only-testing:KeypunchTests test

# UI tests only
xcodebuild -project Keypunch.xcodeproj -scheme Keypunch -destination 'platform=macOS' -only-testing:KeypunchUITests test
```

## Tech Stack

- SwiftUI (`NSStatusItem` + `NSWindow`)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for global hotkey registration
- `@Observable` for state management
- UserDefaults for persistence

## License

MIT
