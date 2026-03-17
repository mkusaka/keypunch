# Keypunch

A macOS menu bar app that launches applications via global keyboard shortcuts.

<p align="center">
  <img src="assets/screenshot.png" alt="Keypunch Settings Window" width="400">
</p>

## Features

- Register global keyboard shortcuts to launch any macOS application
- Menu bar icon with Show / Start at Login / Quit controls
- Settings window to add, edit, and remove shortcuts with app icons and shortcut badges
- Persistent storage — shortcuts survive app restarts
- Duplicate app detection

## Install

### Homebrew

```bash
brew install --cask mkusaka/tap/keypunch
```

### Manual Download

Download the latest `.zip` from [GitHub Releases](https://github.com/mkusaka/keypunch/releases), extract it, and move `Keypunch.app` to `/Applications`.

GitHub Releases and the Homebrew cask are signed with a Developer ID certificate and notarized by Apple, so Gatekeeper should allow normal launch after download.

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

## Release Automation

This workflow uses App Store Connect API credentials for cloud-managed `Developer ID` signing and `notarytool`, so no `.p12` is stored in GitHub.

Signed releases require these GitHub repository secrets:

- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`: Base64-encoded App Store Connect API key (`.p8`) used for cloud signing and `notarytool`
- `APPLE_APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID
- `APPLE_APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID

The Apple account running releases must have access to cloud-managed Developer ID certificates and App Store Connect API keys.

### App Store Connect Setup

1. Sign in to App Store Connect as the Apple Developer Account Holder and open `Users and Access`.
2. Open `Integrations` and request access to the App Store Connect API if it is not enabled yet.
3. Create a Team API key with `Admin` access and download the `.p8` file. This workflow expects a Team key, not an Individual key, because it uses the issuer ID and cloud-managed `Developer ID` signing during export.
4. Confirm that cloud-managed certificates are enabled in Apple Developer and that your account can use cloud-managed `Developer ID` certificates.
5. Add `APPLE_TEAM_ID`, `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`, `APPLE_APP_STORE_CONNECT_KEY_ID`, `APPLE_APP_STORE_CONNECT_ISSUER_ID`, and `HOMEBREW_TAP_TOKEN` to the repository's GitHub Actions secrets.
6. Base64-encode the contents of `AuthKey_XXXXXX.p8` and store the result in `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`.
7. Run the workflow manually or with a test tag once to confirm that archive, export, and notarization all succeed. If export fails with a cloud signing permission error, recreate the Team API key with `Admin` access and update the GitHub Actions secrets.

### Certificate Rotation And Monitoring

With cloud-managed certificates, Apple handles certificate rotation automatically. When a new signing request occurs, Apple can create a replacement certificate within the 90-day renewal window, and Xcode 13+ distribution workflows can use cloud signing.

Apple's App Store Connect webhooks do not expose a dedicated certificate-expiry event, so there is no built-in way for Apple to push a "certificate is about to expire" notification directly to SNS or Slack.

In practice, that leaves two options:

- Rely on cloud-managed signing and leave the setup alone after the initial configuration
- Add your own monitoring, such as a scheduled GitHub Actions run or Lambda job that dry-runs archive/export and sends failures to SNS or Slack

### Manual Validation Run

The `Release` workflow also supports `workflow_dispatch`. Manual runs use the `version` input as `MARKETING_VERSION` and execute `archive` -> `exportArchive` -> `notarytool` -> `stapler`. The `version` input only accepts digits and dots, for example `1.2.3`.

Manual runs skip these publication steps:

- GitHub Release creation
- `repository_dispatch` to the Homebrew tap

`notarytool submit` uses `--wait --timeout 1h`, so the workflow waits for notarization to finish but fails after one hour if Apple has not returned a result.

Local `xcodebuild` builds remain unsigned unless you sign them with your own Apple certificate.

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
